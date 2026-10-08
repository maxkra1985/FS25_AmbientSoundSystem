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
	self.scheduler = AmbientSoundScheduler.new(self.configs)
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
-- Создание экземпляра звука
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:createRuntimeSound(config)
	if config == nil then
		return nil
	end
	local position = self:getSpawnPosition(config)
	if position == nil then
		TaigaAmbientSoundUtil.warning("Не удалось определить позицию появления для ID=%d", config.id)
		return nil
	end

	local runtimeSound = AmbientSound.new()
	runtimeSound:setConfig(config)
	runtimeSound.runtimeId = self.nextRuntimeId
	self.nextRuntimeId = self.nextRuntimeId + 1
	runtimeSound:setPosition(position)
	if not runtimeSound:load() then
		TaigaAmbientSoundUtil.warning("Ошибка загрузки Runtime #%d",runtimeSound.runtimeId)
		return nil
	end

	self.activeSounds[runtimeSound.runtimeId] = runtimeSound
	TaigaAmbientSoundUtil.debug("Создан Runtime #%d (config=%d)", runtimeSound.runtimeId, config.id)

	if config.type == "global" then
		if TaigaAmbientSoundUtil.isServer() then
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
function TaigaAmbientSoundSystem:updateRuntimeSounds(dt)
	local removeList = {}
	for runtimeId, runtimeSound in pairs(self.activeSounds) do
		local alive = runtimeSound:update(dt)
		if alive then
			-- Если звук движется, сервер синхронизирует позицию
			if runtimeSound:isMoving()
				and runtimeSound.config.type == "global"
				and TaigaAmbientSoundUtil.isServer() then
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
function TaigaAmbientSoundSystem:removeRuntimeSound(runtimeId)
	local runtimeSound = self.activeSounds[runtimeId]
	if runtimeSound == nil then
		return
	end

	-- Если это глобальный звук, сообщаем клиентам
	if runtimeSound.config.type == "global" and TaigaAmbientSoundUtil.isServer() then
		AmbientSoundStopEvent.sendEvent(runtimeId)
	end

	runtimeSound:delete()
	self.activeSounds[runtimeId] = nil
	collectgarbage("step")
	TaigaAmbientSoundUtil.debug("Удалён Runtime #%d", runtimeId)
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
function TaigaAmbientSoundSystem:getFlyPosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end
	local x, y, z = TaigaAmbientSoundUtil.getPlayerWorldPosition(player)
	return TaigaAmbientSoundUtil.randomPointInRadius(x, y + (config.heightOffset or 1.6), z, config.distancePlayer or 1.0)
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
function TaigaAmbientSoundSystem:getRuntimeCount()
	local count = 0
	for _, _ in pairs(self.activeSounds) do
		count = count + 1
	end
	return count
end

------------------------------------------------------------------------------
-- Остановка всех активных звуков
------------------------------------------------------------------------------
function TaigaAmbientSoundSystem:stopAll()
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
		TaigaAmbientSoundUtil.info("Runtime #%d (%s)", runtimeId, tostring(runtimeSound.config.name or runtimeSound.config.id))
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
