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

AmbientSoundSystem = {}
local AmbientSoundSystem_mt = Class(AmbientSoundSystem)

------------------------------------------------------------------------------
-- Создание объекта
------------------------------------------------------------------------------

function AmbientSoundSystem.new(customMt)
	local self = setmetatable({}, customMt or AmbientSoundSystem_mt)

	-- Конфигурация
	self.soundFiles = {}
	self.configs = {}
	self.configsById = {}

	-- Активные экземпляры
	self.activeSounds = {}
	self.nextRuntimeId = 1

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
function AmbientSoundSystem:initialize(xmlFilename)
	if self.initialized then
		return true
	end

	if xmlFilename ~= nil then
		self.xmlFilename = xmlFilename
	end

	AmbientSoundUtil.info("----------------------------------------")
	AmbientSoundUtil.info("Инициализация Ambient Sound System из %s'",tostring(self.xmlFilename))
	AmbientSoundUtil.info("----------------------------------------")

	-- Загрузка XML
	local soundFiles, configs = AmbientSoundXML.load(self.xmlFilename)
	if soundFiles == nil or configs == nil then
		AmbientSoundUtil.error("Не удалось загрузить '%s'",tostring(self.xmlFilename))
		return false
	end
	self.soundFiles = soundFiles
	self.configs = configs

	-- Индексация конфигураций
	self.configsById = {}
	for _, config in ipairs(self.configs) do
		self.configsById[config.id] = config
	end
	AmbientSoundUtil.info("Загружено файлов: %d", #self.soundFiles)
	AmbientSoundUtil.info("Загружено конфигураций: %d", #self.configs)

	-- Создание Scheduler
	self.scheduler = AmbientSoundScheduler.new(self.configs)
	AmbientSoundUtil.info("Scheduler создан")
	if self.scheduler ~= nil then
		self.scheduler:reset()
	end
	self.initialized = true
	AmbientSoundUtil.info("Система успешно запущена.")
	return true
end

------------------------------------------------------------------------------
-- Основное обновление
------------------------------------------------------------------------------
function AmbientSoundSystem:update(dt)
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
-- Создание экземпляра звука
------------------------------------------------------------------------------
function AmbientSoundSystem:createRuntimeSound(config)
	if config == nil then
		return nil
	end
	local position = self:getSpawnPosition(config)
	if position == nil then
		AmbientSoundUtil.warning("Не удалось определить позицию появления для ID=%d", config.id)
		return nil
	end

	local runtimeSound = AmbientSound.new()
	runtimeSound:setConfig(config)
	runtimeSound.runtimeId = self.nextRuntimeId
	self.nextRuntimeId = self.nextRuntimeId + 1
	runtimeSound:setPosition(position)
	if not runtimeSound:load() then
		AmbientSoundUtil.warning("Ошибка загрузки Runtime #%d",runtimeSound.runtimeId)
		return nil
	end

	self.activeSounds[runtimeSound.runtimeId] = runtimeSound
	AmbientSoundUtil.debug("Создан Runtime #%d (config=%d)", runtimeSound.runtimeId, config.id)

	if config.type == "global" then
		if AmbientSoundUtil.isServer() then
			runtimeSound:play()
			AmbientSoundPlayEvent.sendEvent(runtimeSound.runtimeId, config.id, position)
		end
	else
		runtimeSound:play()
	end

	return runtimeSound
end

------------------------------------------------------------------------------
-- Обновление активных экземпляров
------------------------------------------------------------------------------
function AmbientSoundSystem:updateRuntimeSounds(dt)
	local removeList = {}
	for runtimeId, runtimeSound in pairs(self.activeSounds) do
		local alive = runtimeSound:update(dt)
		if alive then
			-- Если звук движется, сервер синхронизирует позицию
			if runtimeSound:isMoving()
				and runtimeSound.config.type == "global"
				and AmbientSoundUtil.isServer() then
				local position = runtimeSound:getPosition()
				AmbientSoundMoveEvent.sendEvent(
					runtimeId,
					position.x,
					position.y,
					position.z
				)
			end

			-- Закончил воспроизведение
			if runtimeSound:isFinished() then
				table.insert(removeList, runtimeId)
			end
		else
			table.insert(removeList, runtimeId)
		end
	end
	for _, runtimeId in ipairs(removeList) do
		self:removeRuntimeSound(runtimeId)
	end
end

------------------------------------------------------------------------------
-- Удаление Runtime экземпляра
------------------------------------------------------------------------------
function AmbientSoundSystem:removeRuntimeSound(runtimeId)
	local runtimeSound = self.activeSounds[runtimeId]
	if runtimeSound == nil then
		return
	end

	-- Если это глобальный звук, сообщаем клиентам
	if runtimeSound.config.type == "global" and AmbientSoundUtil.isServer() then
		AmbientSoundStopEvent.sendEvent(runtimeId)
	end

	runtimeSound:delete()
	self.activeSounds[runtimeId] = nil
	collectgarbage("step")
	AmbientSoundUtil.debug("Удалён Runtime #%d", runtimeId)
end

------------------------------------------------------------------------------
-- Получение Runtime экземпляра
------------------------------------------------------------------------------
function AmbientSoundSystem:getRuntimeSound(runtimeId)
	return self.activeSounds[runtimeId]
end

------------------------------------------------------------------------------
-- Получение конфигурации
------------------------------------------------------------------------------
function AmbientSoundSystem:getConfig(configId)
	return self.configsById[configId]
end

------------------------------------------------------------------------------
-- Определение позиции появления
------------------------------------------------------------------------------
function AmbientSoundSystem:getSpawnPosition(config)
	if config.mode == "static" then
		return self:getStaticPosition(config)
	elseif config.mode == "running" then
		return self:getRunningPosition(config)
	elseif config.mode == "fly" then
		return self:getFlyPosition(config)
	end
	AmbientSoundUtil.warning("Неизвестный режим '%s'",tostring(config.mode))
	return nil
end

------------------------------------------------------------------------------
-- Статическая позиция
------------------------------------------------------------------------------
function AmbientSoundSystem:getStaticPosition(config)
	if config.translation == nil then
		return nil
	end
	local position = { x = config.translation.x, y = config.translation.y, z = config.translation.z}
	if config.randomRadius ~= nil
		and config.randomRadius > 0 then
		position = AmbientSoundUtil.randomPointInRadius(position.x, position.y, position.z, config.randomRadius)
	end
	return position
end

------------------------------------------------------------------------------
-- Позиция бегущего объекта
------------------------------------------------------------------------------
function AmbientSoundSystem:getRunningPosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end

	local x, y, z = AmbientSoundUtil.getPlayerWorldPosition(player)
	local distance = config.distancePlayer or 120
	return AmbientSoundUtil.randomPointOnRadius(x, y, z, distance)
end

------------------------------------------------------------------------------
-- Позиция локального летающего объекта
------------------------------------------------------------------------------
function AmbientSoundSystem:getFlyPosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end
	local x, y, z = AmbientSoundUtil.getPlayerWorldPosition(player)
	return AmbientSoundUtil.randomPointInRadius(x, y + (config.heightOffset or 1.6), z, config.distancePlayer or 1.0)
end

------------------------------------------------------------------------------
-- Получение случайного игрока
------------------------------------------------------------------------------
function AmbientSoundSystem:getRandomPlayer()
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
function AmbientSoundSystem:getRuntimeCount()
	local count = 0
	for _, _ in pairs(self.activeSounds) do
		count = count + 1
	end
	return count
end

------------------------------------------------------------------------------
-- Остановка всех активных звуков
------------------------------------------------------------------------------
function AmbientSoundSystem:stopAll()
	local runtimeIds = {}
	for runtimeId, _ in pairs(self.activeSounds) do
		table.insert(runtimeIds, runtimeId)
	end
	table.sort(runtimeIds)
	for _, runtimeId in ipairs(runtimeIds) do
		self:removeRuntimeSound(runtimeId)
	end
end

------------------------------------------------------------------------------
-- Включение / отключение системы
------------------------------------------------------------------------------
function AmbientSoundSystem:setEnabled(state)
	self.enabled = state == true
	AmbientSoundUtil.info("Ambient Sound System %s", self.enabled and "включена" or "отключена")
end

------------------------------------------------------------------------------
-- Проверка активности
------------------------------------------------------------------------------
function AmbientSoundSystem:isEnabled()
	return self.enabled
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundSystem:printDebug()
	AmbientSoundUtil.info("----------------------------------------")
	AmbientSoundUtil.info("Статистика Ambient Sound System")
	AmbientSoundUtil.info("----------------------------------------")
	AmbientSoundUtil.info("Конфигураций: %d", #self.configs)
	AmbientSoundUtil.info("Активных экземпляров: %d", self:getRuntimeCount())
	AmbientSoundUtil.info("Следующий Runtime ID: %d", self.nextRuntimeId)
	for runtimeId, runtimeSound in pairs(self.activeSounds) do
		AmbientSoundUtil.info("Runtime #%d (%s)", runtimeId, tostring(runtimeSound.config.name or runtimeSound.config.id))
	end
end

------------------------------------------------------------------------------
-- Очистка системы
------------------------------------------------------------------------------
function AmbientSoundSystem:delete()
	AmbientSoundUtil.info("Остановка Ambient Sound System...")
	self:stopAll()
	if self.scheduler ~= nil then
		self.scheduler:delete()
		self.scheduler = nil
	end
	self.nextRuntimeId = 1
	self.configs = {}
	self.configsById = {}
	self.soundFiles = {}
	self.initialized = false

	if g_ambientSoundSystem == self then
		g_ambientSoundSystem = nil
	end

	AmbientSoundUtil.info("Ambient Sound System остановлена.")
	self.enabled = false
end

------------------------------------------------------------------------------
-- Проверка существования Runtime
------------------------------------------------------------------------------

function AmbientSoundSystem:hasRuntime(runtimeId)
	return self.activeSounds[runtimeId] ~= nil
end

------------------------------------------------------------------------------
-- Получение списка активных Runtime
------------------------------------------------------------------------------
function AmbientSoundSystem:getActiveSounds()
	return self.activeSounds
end
