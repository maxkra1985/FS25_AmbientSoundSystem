------------------------------------------------------------------------------
-- AmbientSoundSystem.lua
--
-- Ambient Sound System v2.0
--
-- Главный менеджер системы окружающих звуков.
--
-- Отвечает за:
--   • загрузку конфигурации;
--   • создание Scheduler;
--   • создание Runtime экземпляров;
--   • обновление активных звуков;
--   • сетевую синхронизацию;
--   • удаление экземпляров.
--
-- Сам НЕ занимается:
--   • проигрыванием Sample;
--   • логикой движения;
--   • чтением XML.
------------------------------------------------------------------------------
AmbientSoundSystem = {}
local AmbientSoundSystem_mt = Class(AmbientSoundSystem)

------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------
function AmbientSoundSystem.new(customMt)
	local self = setmetatable({}, customMt or AmbientSoundSystem_mt)
	-- Конфигурация
	self.soundFiles = {}
	self.configs = {}
	self.configsById = {}
	-- Runtime
	-- runtimeId -> AmbientSound
	self.activeSounds = {}
	self.nextRuntimeId = 1
	-- Scheduler
	self.scheduler = nil
	-- Состояние системы
	self.enabled = true
	self.initialized = false
	-- XML
	self.xmlFilename = "ambientSounds.xml"
	return self
end

------------------------------------------------------------------------------
-- Инициализация
------------------------------------------------------------------------------
function AmbientSoundSystem:initialize()
	if self.initialized then
		return true
	end
	AmbientSoundUtil.info("========================================")
	AmbientSoundUtil.info("Запуск Ambient Sound System")
	AmbientSoundUtil.info("========================================")
	-- Загружаем XML
	self.soundFiles,
	self.configs = AmbientSoundXML.load(self.xmlFilename)
	-- Индексация конфигураций
	self:buildConfigIndex()
	-- Создаем Scheduler
	self.scheduler = AmbientSoundScheduler.new(
			self.configs,
			function(config)
				self:onSchedulerTrigger(config)
			end
		)
	self.scheduler:reset()
	-- Глобальная ссылка
	g_ambientSoundSystem = self
	self.initialized = true
	AmbientSoundUtil.info("Загружено конфигураций: %d", table.count(self.configs))
	AmbientSoundUtil.info("Ambient Sound System успешно запущена")
	return true
end

------------------------------------------------------------------------------
-- Создание быстрого индекса конфигураций
------------------------------------------------------------------------------
function AmbientSoundSystem:buildConfigIndex()
	self.configsById = {}
	for _, config in ipairs(self.configs) do
		self.configsById[config.id] = config
		config.fileCache = self.soundFiles
		AmbientSoundUtil.debug("Конфигурация %d проиндексирована", config.id)
	end
end

------------------------------------------------------------------------------
-- Обновление системы
------------------------------------------------------------------------------
function AmbientSoundSystem:update(dt)
	if not self.enabled then
		return
	end
	if not self.initialized then
		return
	end
	-- Scheduler
	if self.scheduler ~= nil then
		self.scheduler:update(dt)
	end
	-- Runtime
	self:updateRuntimeSounds(dt)
end

------------------------------------------------------------------------------
-- Callback Scheduler
------------------------------------------------------------------------------
function AmbientSoundSystem:onSchedulerTrigger(config)
	if config == nil then
		return
	end
	self:createRuntimeSound(config)
end

------------------------------------------------------------------------------
-- Создание Runtime экземпляра
------------------------------------------------------------------------------
function AmbientSoundSystem:createRuntimeSound(config)
	if config == nil then
		return nil
	end

	-- Определяем позицию появления
	local position = self:getSpawnPosition(config)
	if position == nil then
		AmbientSoundUtil.warning("Не удалось определить позицию появления звука ID=%d", config.id)
		return nil
	end

	-- Создаем Runtime объект
	local runtimeSound = AmbientSound.new(config, position)

	-- Назначаем Runtime ID
	runtimeSound.runtimeId = self.nextRuntimeId
	self.nextRuntimeId = self.nextRuntimeId + 1

	-- Загружаем Sample
	if not runtimeSound:load() then
		AmbientSoundUtil.warning("Не удалось загрузить RuntimeSound %d",runtimeSound.runtimeId)
		return nil
	end

	-- Регистрируем экземпляр
	self.activeSounds[runtimeSound.runtimeId] = runtimeSound
	AmbientSoundUtil.debug("Создан RuntimeSound #%d (config=%d)", runtimeSound.runtimeId, config.id)

	-- Запуск
	if config.type == "global" then
		-- Сервер запускает локально
		if AmbientSoundUtil.isServer() then
			runtimeSound:play()
			AmbientSoundPlayEvent.sendEvent(runtimeSound.runtimeId, config.id, position, config.volume)
		end
	else
		-- Локальный звук
		runtimeSound:play()
	end
	return runtimeSound
end

------------------------------------------------------------------------------
-- Поиск Runtime объекта
------------------------------------------------------------------------------
function AmbientSoundSystem:getRuntimeSound(runtimeId)
	return self.activeSounds[runtimeId]
end

------------------------------------------------------------------------------
-- Удаление Runtime объекта
------------------------------------------------------------------------------
function AmbientSoundSystem:removeRuntimeSound(runtimeId)
	local runtimeSound = self.activeSounds[runtimeId]
	if runtimeSound == nil then
		return
	end

	-- MP
	if runtimeSound.config.type == "global" and AmbientSoundUtil.isServer() then
		AmbientSoundStopEvent.sendEvent(runtimeId)
	end

	-- Удаляем объект
	runtimeSound:stop()
	runtimeSound:delete()
	self.activeSounds[runtimeId] = nil
	AmbientSoundUtil.debug("RuntimeSound #%d удалён", runtimeId)
end

------------------------------------------------------------------------------
-- Получение конфигурации
------------------------------------------------------------------------------
function AmbientSoundSystem:getConfig(configId)
	return self.configsById[configId]
end

------------------------------------------------------------------------------
-- Обновление всех Runtime объектов
------------------------------------------------------------------------------
function AmbientSoundSystem:updateRuntimeSounds(dt)
	for runtimeId, runtimeSound in pairs(self.activeSounds) do
		runtimeSound:update(dt)
		-- Движение глобального объекта
		if runtimeSound:isMoving() and runtimeSound.config.type == "global" and AmbientSoundUtil.isServer() then
			AmbientSoundMoveEvent.sendEvent(runtimeId, runtimeSound:getPosition())
		end

		-- Проверка завершения
		if runtimeSound:isFinished() then
			self:removeRuntimeSound(runtimeId)
		end
	end
end

------------------------------------------------------------------------------
-- Определение позиции появления
------------------------------------------------------------------------------
function AmbientSoundSystem:getSpawnPosition(config)
	if config == nil then
		return nil
	end

	-- Статическая точка
	if config.mode == "static" then
		return self:getStaticPosition(config)
	end

	-- Бегущий объект
	if config.mode == "running" then
		return self:getPlayerDistancePosition(config)
	end

	-- Летающий объект
	if config.mode == "fly" then
		return self:getPlayerFlyPosition(config)
	end

	AmbientSoundUtil.warning("Неизвестный режим '%s'", tostring(config.mode))
	return nil
end

------------------------------------------------------------------------------
-- Статическая позиция
------------------------------------------------------------------------------
function AmbientSoundSystem:getStaticPosition(config)
	if config.translation == nil then
		return nil
	end
	local position = {
		x = config.translation.x,
		y = config.translation.y,
		z = config.translation.z
	}

	if config.randomRadius ~= nil and config.randomRadius > 0 then
		position = AmbientSoundUtil.randomPointInRadius( position.x, position.y, position.z, config.randomRadius)
	end
	return position
end

------------------------------------------------------------------------------
-- Позиция на расстоянии от случайного игрока
------------------------------------------------------------------------------
function AmbientSoundSystem:getPlayerDistancePosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end

	local x, y, z = getWorldTranslation(player.rootNode)
	local distance = config.distancePlayer or 100
	return AmbientSoundUtil.randomPointOnRadius(x, y, z, distance)
end

------------------------------------------------------------------------------
-- Позиция около игрока
------------------------------------------------------------------------------
function AmbientSoundSystem:getPlayerFlyPosition(config)
	local player = self:getRandomPlayer()
	if player == nil then
		return nil
	end

	local x, y, z = getWorldTranslation(player.rootNode)
	local radius = config.distancePlayer or 1.5
	return AmbientSoundUtil.randomPointInRadius(x, y + 1.6, z, radius)
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
	local count = 0
	for _, _ in pairs(players) do
		count = count + 1
	end
	if count == 0 then
		return nil
	end
	local index = math.random(count)
	local current = 1
	for _, player in pairs(players) do
		if current == index then
			return player
		end
		current = current + 1
	end
	return nil
end

------------------------------------------------------------------------------
-- Остановка всех Runtime объектов
------------------------------------------------------------------------------
function AmbientSoundSystem:stopAll()
	local removeList = {}
	for runtimeId, _ in pairs(self.activeSounds) do
		table.insert(removeList, runtimeId)
	end

	for _, runtimeId in ipairs(removeList) do
		self:removeRuntimeSound(runtimeId)
	end
end

------------------------------------------------------------------------------
-- Включение системы
------------------------------------------------------------------------------
function AmbientSoundSystem:setEnabled(state)
	self.enabled = state == true
	AmbientSoundUtil.info("Ambient Sound System %s", self.enabled and "включена" or "выключена")
end

------------------------------------------------------------------------------
-- Проверка активности
------------------------------------------------------------------------------
function AmbientSoundSystem:isEnabled()
	return self.enabled
end

------------------------------------------------------------------------------
-- Количество активных Runtime объектов
------------------------------------------------------------------------------
function AmbientSoundSystem:getRuntimeCount()
	local count = 0
	for _, _ in pairs(self.activeSounds) do
		count = count + 1
	end
	return count
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundSystem:printDebug()
	AmbientSoundUtil.info("----------------------------------------")
	AmbientSoundUtil.info("Статистика Ambient Sound System")
	AmbientSoundUtil.info("----------------------------------------")
	AmbientSoundUtil.info("Конфигураций: %d", table.count(self.configs))
	AmbientSoundUtil.info("Активных Runtime: %d", self:getRuntimeCount())
	AmbientSoundUtil.info("Следующий RuntimeID: %d", self.nextRuntimeId)
end

------------------------------------------------------------------------------
-- Удаление системы
------------------------------------------------------------------------------
function AmbientSoundSystem:delete()
	AmbientSoundUtil.info("Удаление Ambient Sound System...")
	self:stopAll()
	if self.scheduler ~= nil then
		self.scheduler:delete()
		self.scheduler = nil
	end
	self.activeSounds = {}
	self.configs = {}
	self.configsById = {}
	self.soundFiles = {}
	self.initialized = false
	if g_ambientSoundSystem == self then
		g_ambientSoundSystem = nil
	end
	AmbientSoundUtil.info("Ambient Sound System успешно удалена")
end

------------------------------------------------------------------------------
-- Возвращает Runtime объект
------------------------------------------------------------------------------
function AmbientSoundSystem:getRuntime(runtimeId)
	return self.activeSounds[runtimeId]
end

------------------------------------------------------------------------------
-- Возвращает конфигурацию по ID
------------------------------------------------------------------------------
function AmbientSoundSystem:getConfigById(configId)
	return self.configsById[configId]
end

------------------------------------------------------------------------------
-- Проверка существования Runtime объекта
------------------------------------------------------------------------------
function AmbientSoundSystem:hasRuntime(runtimeId)
	return self.activeSounds[runtimeId] ~= nil
end