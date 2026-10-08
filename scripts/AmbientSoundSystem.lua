------------------------------------------------------------------------------
-- AmbientSoundSystem.lua
--
-- Главный менеджер Ambient Sound System
--
-- Отвечает за:
--   • загрузку XML;
--   • создание экземпляров AmbientSound;
--   • работу Scheduler;
--   • обновление звуков;
--   • синхронизацию мультиплеера.
------------------------------------------------------------------------------

TaigaAmbientSoundSystem = {}
local TaigaAmbientSoundSystem_mt = Class(TaigaAmbientSoundSystem)

------------------------------------------------------------------------------
-- Создание объекта
------------------------------------------------------------------------------

function TaigaAmbientSoundSystem.new(customMt)
	local self = setmetatable({}, customMt or TaigaAmbientSoundSystem_mt)

	-- Конфигурация
	self.soundFiles = {}
	self.configs = {}
	self.configsById = {}

	-- Активные экземпляры
	self.activeSounds = {} -- только глобальные, ID выдаёт сервер
	self.localSounds = {}  -- только локальные звуки этого игрока
	self.nextRuntimeId = 1
	self.nextLocalRuntimeId = 1

	-- Scheduler
	self.scheduler = nil

	-- Состояние
	self.enabled = true
	self.initialized = false

	-- XML
	self.xmlFilename = nil
	return self
end

------------------------------------------------------------------------------
-- Инициализация
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:initialize(xmlFilename, baseDirectory)
	if self.initialized then
		return true
	end

	if xmlFilename ~= nil then
		self.xmlFilename = xmlFilename
	end

	TaigaAmbientSoundUtil.info("----------------------------------------")
	TaigaAmbientSoundUtil.info("Инициализация Ambient Sound System из %s'",tostring(self.xmlFilename))
	TaigaAmbientSoundUtil.info("----------------------------------------")

	-- Загрузка XML
	local soundFiles, configs = AmbientSoundXML.load(self.xmlFilename, baseDirectory)
	if soundFiles == nil or configs == nil then
		TaigaAmbientSoundUtil.error("Не удалось загрузить '%s'",tostring(self.xmlFilename))
		return false
	end
	self.soundFiles = soundFiles
	self.configs = configs

	-- Индексация конфигураций
	self.configsById = {}
	for _, config in ipairs(self.configs) do
		self.configsById[config.id] = config
	end
	TaigaAmbientSoundUtil.info("Загружено файлов: %d", #self.soundFiles)
	TaigaAmbientSoundUtil.info("Загружено конфигураций: %d", #self.configs)

	-- Создание Scheduler
	-- Сервер планирует global, каждый игровой клиент планирует только свои local.
	-- На хосте оба типа работают в одной системе, но в разных таблицах.
	local scheduledConfigs = {}
	for _, config in ipairs(self.configs) do
		if config.type == "global" and TaigaAmbientSoundUtil.isServer()
			or config.type == "local" and g_dedicatedServer == nil then
			table.insert(scheduledConfigs, config)
		end
	end
	self.scheduler = AmbientSoundScheduler.new(scheduledConfigs)
	TaigaAmbientSoundUtil.info("Scheduler создан")
	if self.scheduler ~= nil then
		self.scheduler:reset()
	end
	self.initialized = true
	TaigaAmbientSoundUtil.info("Система успешно запущена.")
	return true
end

------------------------------------------------------------------------------
-- Основное обновление
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:update(dt)
	if not self.enabled then
		return
	end
	if not self.initialized then
		return
	end

	-- Получаем список конфигураций,
	-- время которых наступило.
	local readyConfigs = self.scheduler:update(dt)
	if readyConfigs ~= nil then
		for _, config in ipairs(readyConfigs) do
			self:createRuntimeSound(config)
		end
	end

	-- Обновляем активные экземпляры
	self:updateRuntimeSounds(dt)
end

------------------------------------------------------------------------------
-- Выдача сетевого ID
------------------------------------------------------------------------------
-- Возвращает свободный ID из диапазона UInt16, используемого в событиях.
function TaigaAmbientSoundSystem:allocateRuntimeId()
    for _ = 1, 65535 do
        local runtimeId = self.nextRuntimeId
        self.nextRuntimeId = runtimeId % 65535 + 1
        if self.activeSounds[runtimeId] == nil then
            return runtimeId
        end
    end
    TaigaAmbientSoundUtil.warning("Все идентификаторы глобальных звуков заняты.")
    return nil
end

------------------------------------------------------------------------------
-- Создание экземпляра звука
------------------------------------------------------------------------------
-- Global создаётся только сервером, local — только на машине с локальным игроком.
function TaigaAmbientSoundSystem:createRuntimeSound(config)
    if config == nil then
        return nil
    end

    local isGlobal = config.type == "global"
    if isGlobal then
        if not TaigaAmbientSoundUtil.isServer() then
            return nil
        end
    elseif config.type == "local" then
        if g_dedicatedServer ~= nil then
            return nil
        end
        local playerSystem = g_currentMission ~= nil and g_currentMission.playerSystem or nil
        if playerSystem == nil or playerSystem:getLocalPlayer() == nil then
            return nil
        end
    else
        TaigaAmbientSoundUtil.warning("Неизвестный тип звука: %s", tostring(config.type))
        return nil
    end

    local position = self:getSpawnPosition(config)
    if position == nil then
        TaigaAmbientSoundUtil.warning("Не удалось определить позицию для config=%d", config.id)
        return nil
    end

    local runtimeId
    if isGlobal then
        runtimeId = self:allocateRuntimeId()
        if runtimeId == nil then
            return nil
        end
    else
        runtimeId = self.nextLocalRuntimeId
        self.nextLocalRuntimeId = self.nextLocalRuntimeId + 1
    end

    local runtimeSound = AmbientSound.new()
    runtimeSound:setConfig(config)
    runtimeSound.runtimeId = runtimeId
    runtimeSound:setPosition(position)

    if not runtimeSound:load() then
        runtimeSound:delete()
        return nil
    end
    if not runtimeSound:play() then
        runtimeSound:delete()
        return nil
    end

    if isGlobal then
        self.activeSounds[runtimeId] = runtimeSound
        -- Клиенты получают точный индекс варианта, выбранный сервером.
        AmbientSoundPlayEvent.sendEvent(runtimeId, config.id, runtimeSound.soundIndex, position)
    else
        self.localSounds[runtimeId] = runtimeSound
    end
    TaigaAmbientSoundUtil.debug("Создан %s Runtime #%d (config=%d)", config.type, runtimeId, config.id)
    return runtimeSound
end

------------------------------------------------------------------------------
-- Обновление активных экземпляров
------------------------------------------------------------------------------
-- Сервер сообщает об изменении позиции global, а клиент ждёт серверной команды Stop.
function TaigaAmbientSoundSystem:updateRuntimeSounds(dt)
    local isServer = TaigaAmbientSoundUtil.isServer()
    local removeGlobal = {}

    for runtimeId, runtimeSound in pairs(self.activeSounds) do
        local alive, moved = runtimeSound:update(dt)
        if isServer then
            if moved and runtimeSound:isMoving() then
                local position = runtimeSound:getPosition()
                AmbientSoundMoveEvent.sendEvent(runtimeId, position.x, position.y, position.z)
            end
            if not alive or runtimeSound:isFinished() then
                table.insert(removeGlobal, runtimeId)
            end
        end
        -- Клиент не уничтожает глобальный Runtime самостоятельно.
        -- Даже если воспроизведение завершилось, ожидаем серверный StopEvent.
    end

    for _, runtimeId in ipairs(removeGlobal) do
        self:removeRuntimeSound(runtimeId)
    end

    local removeLocal = {}
    for runtimeId, runtimeSound in pairs(self.localSounds) do
        local alive = runtimeSound:update(dt)
        if not alive or runtimeSound:isFinished() then
            table.insert(removeLocal, runtimeId)
        end
    end
    for _, runtimeId in ipairs(removeLocal) do
        self:removeRuntimeSound(runtimeId, true)
    end
end

------------------------------------------------------------------------------
-- Удаление Runtime экземпляра
------------------------------------------------------------------------------
-- Удаляет звук из соответствующего пространства ID и синхронизирует Stop для global.
function TaigaAmbientSoundSystem:removeRuntimeSound(runtimeId, isLocal)
    local sounds = isLocal and self.localSounds or self.activeSounds
    local runtimeSound = sounds[runtimeId]
    if runtimeSound == nil then
        return
    end

    if not isLocal and TaigaAmbientSoundUtil.isServer() then
        AmbientSoundStopEvent.sendEvent(runtimeId)
    end

    runtimeSound:delete()
    sounds[runtimeId] = nil
    collectgarbage("step")
    TaigaAmbientSoundUtil.debug("Удалён %s Runtime #%d", isLocal and "local" or "global", runtimeId)
end

------------------------------------------------------------------------------
-- Начальное состояние нового клиента
------------------------------------------------------------------------------
-- Посылает вновь подключившемуся клиенту активные global с их точными вариантами.
function TaigaAmbientSoundSystem:sendActiveGlobalSounds(connection)
    if not self.initialized or not TaigaAmbientSoundUtil.isServer() or connection == nil then
        return
    end

    for runtimeId, runtimeSound in pairs(self.activeSounds) do
        if runtimeSound.playing and runtimeSound.soundIndex ~= nil then
            connection:sendEvent(AmbientSoundPlayEvent.new(
                runtimeId, runtimeSound.config.id, runtimeSound.soundIndex, runtimeSound:getPosition()
            ))
        end
    end
end

------------------------------------------------------------------------------
-- Получение Runtime экземпляра
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getRuntimeSound(runtimeId)
	return self.activeSounds[runtimeId]
end

------------------------------------------------------------------------------
-- Получение конфигурации
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getConfig(configId)
	return self.configsById[configId]
end

------------------------------------------------------------------------------
-- Определение позиции появления
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getSpawnPosition(config)
	if config.mode == "static" then
		return self:getStaticPosition(config)
	elseif config.mode == "running" then
		return self:getRunningPosition(config)
	elseif config.mode == "fly" then
		return self:getFlyPosition(config)
	end
	TaigaAmbientSoundUtil.warning("Неизвестный режим '%s'",tostring(config.mode))
	return nil
end

------------------------------------------------------------------------------
-- Статическая позиция
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getStaticPosition(config)
	if config.translation == nil then
		return nil
	end
	local position = { x = config.translation.x, y = config.translation.y, z = config.translation.z}
	if config.randomRadius ~= nil
		and config.randomRadius > 0 then
		position = TaigaAmbientSoundUtil.randomPointInRadius(position.x, position.y, position.z, config.randomRadius)
	end
	return position
end

------------------------------------------------------------------------------
-- Позиция бегущего объекта
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getRunningPosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end

	local x, y, z = TaigaAmbientSoundUtil.getPlayerWorldPosition(player)
	local distance = config.distancePlayer or 120
	return TaigaAmbientSoundUtil.randomPointOnRadius(x, y, z, distance)
end

------------------------------------------------------------------------------
-- Позиция локального летающего объекта
------------------------------------------------------------------------------
-- Муха и комар всегда появляются у местного игрока, а не у случайного участника.
function TaigaAmbientSoundSystem:getFlyPosition(config)
    local playerSystem = g_currentMission ~= nil and g_currentMission.playerSystem or nil
    if playerSystem == nil then
        return nil
    end

    local player = playerSystem:getLocalPlayer()
    if player == nil or player.rootNode == nil then
        return nil
    end

    local x, y, z = TaigaAmbientSoundUtil.getPlayerWorldPosition(player)
    return TaigaAmbientSoundUtil.randomPointInRadius(
        x, y + (config.heightOffset or 1.6), z, config.distancePlayer or 1.0
    )
end

------------------------------------------------------------------------------
-- Получение случайного игрока
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getRandomPlayer()
	if g_currentMission == nil then
		return nil
	end

	local playerSystem = g_currentMission.playerSystem
	if playerSystem == nil then
		return nil
	end

	local players = playerSystem.players
	if players == nil then
		return nil
	end

	local list = {}
	for _, player in pairs(players) do
		if player ~= nil and player.rootNode ~= nil then
			table.insert(list, player)
		end
	end

	if #list == 0 then
		return nil
	end
	return list[math.random(#list)]
end

------------------------------------------------------------------------------
-- Возвращает количество активных экземпляров
------------------------------------------------------------------------------
-- Считает global и local в обоих независимых пространствах идентификаторов.
function TaigaAmbientSoundSystem:getRuntimeCount()
    local count = 0
    for _ in pairs(self.activeSounds) do
        count = count + 1
    end
    for _ in pairs(self.localSounds) do
        count = count + 1
    end
    return count
end

------------------------------------------------------------------------------
-- Остановка всех активных звуков
------------------------------------------------------------------------------
-- При завершении миссии очищает обе таблицы и отправляет Stop для global на сервере.
function TaigaAmbientSoundSystem:stopAll()
    local globalIds = {}
    for runtimeId in pairs(self.activeSounds) do
        table.insert(globalIds, runtimeId)
    end
    for _, runtimeId in ipairs(globalIds) do
        self:removeRuntimeSound(runtimeId)
    end

    local localIds = {}
    for runtimeId in pairs(self.localSounds) do
        table.insert(localIds, runtimeId)
    end
    for _, runtimeId in ipairs(localIds) do
        self:removeRuntimeSound(runtimeId, true)
    end
end

------------------------------------------------------------------------------
-- Включение / отключение системы
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:setEnabled(state)
	self.enabled = state == true
	TaigaAmbientSoundUtil.info("Ambient Sound System %s", self.enabled and "включена" or "отключена")
end

------------------------------------------------------------------------------
-- Проверка активности
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:isEnabled()
	return self.enabled
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:printDebug()
	TaigaAmbientSoundUtil.info("----------------------------------------")
	TaigaAmbientSoundUtil.info("Статистика Ambient Sound System")
	TaigaAmbientSoundUtil.info("----------------------------------------")
	TaigaAmbientSoundUtil.info("Конфигураций: %d", #self.configs)
	TaigaAmbientSoundUtil.info("Активных экземпляров: %d", self:getRuntimeCount())
	TaigaAmbientSoundUtil.info("Следующий Runtime ID: %d", self.nextRuntimeId)
	for runtimeId, runtimeSound in pairs(self.activeSounds) do
		TaigaAmbientSoundUtil.info("Global #%d (%s)", runtimeId, tostring(runtimeSound.config.name or runtimeSound.config.id))
	end
	for runtimeId, runtimeSound in pairs(self.localSounds) do
		TaigaAmbientSoundUtil.info("Local #%d (%s)", runtimeId, tostring(runtimeSound.config.name or runtimeSound.config.id))
	end
end

------------------------------------------------------------------------------
-- Очистка системы
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:delete()
	TaigaAmbientSoundUtil.info("Остановка Ambient Sound System...")
	self:stopAll()
	if self.scheduler ~= nil then
		self.scheduler:delete()
		self.scheduler = nil
	end
	self.nextRuntimeId = 1
	self.nextLocalRuntimeId = 1
	self.localSounds = {}
	self.configs = {}
	self.configsById = {}
	self.soundFiles = {}
	self.initialized = false

	if g_ambientSoundSystem == self then
		g_ambientSoundSystem = nil
	end

	TaigaAmbientSoundUtil.info("Ambient Sound System остановлена.")
	self.enabled = false
end

------------------------------------------------------------------------------
-- Проверка существования Runtime
------------------------------------------------------------------------------

function TaigaAmbientSoundSystem:hasRuntime(runtimeId)
	return self.activeSounds[runtimeId] ~= nil
end

------------------------------------------------------------------------------
-- Получение списка активных Runtime
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:getActiveSounds()
	return self.activeSounds
end
