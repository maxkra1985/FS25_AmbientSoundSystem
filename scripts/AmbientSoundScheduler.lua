------------------------------------------------------------------------------
-- AmbientSoundScheduler.lua
-- Планировщик воспроизведения окружающих звуков.
-- Отвечает только за определение момента запуска звука.
-- Не занимается созданием, воспроизведением и сетевой синхронизацией.
------------------------------------------------------------------------------
AmbientSoundScheduler = {}
local AmbientSoundScheduler_mt = Class(AmbientSoundScheduler)

------------------------------------------------------------------------------
-- Создание объекта
------------------------------------------------------------------------------
function AmbientSoundScheduler.new(configs, customMt)
	local self = setmetatable({}, customMt or AmbientSoundScheduler_mt)
	self.configs = configs or {}
	TaigaAmbientSoundUtil.info("[AmbientSoundScheduler.new] Конфигураций: %d", #self.configs)
	self.timers = {}
	self.readyConfigs = {}
	-- Запросы принудительного запуска обрабатываются в следующем update().
	self.forcedConfigs = {}
	return self
end

------------------------------------------------------------------------------
-- Инициализация таймеров
------------------------------------------------------------------------------
function AmbientSoundScheduler:reset()
	self.timers = {}
	self.readyConfigs = {}
	self.forcedConfigs = {}
	for _, config in ipairs(self.configs) do
		self.timers[config.id] = math.random(config.minDelay, config.maxDelay)
	end
	TaigaAmbientSoundUtil.debug("[AmbientSoundScheduler.reset] Таймеров установлено: %d", #self.configs)
end

------------------------------------------------------------------------------
-- Обновление
------------------------------------------------------------------------------
function AmbientSoundScheduler:update(dt)
	self.readyConfigs = {}
	local delta = dt / 1000
	for _, config in ipairs(self.configs) do
		local timer = self.timers[config.id]
		if timer ~= nil then
			timer = timer - delta
			self.timers[config.id] = timer
			-- Принудительный запуск выполняется однократно и не зависит от условий.
			if self.forcedConfigs[config.id] then
				self.forcedConfigs[config.id] = nil
				table.insert(self.readyConfigs, config)
				self.timers[config.id] = math.random(config.minDelay, config.maxDelay)
				TaigaAmbientSoundUtil.debug("[Scheduler] Принудительный запуск config=%d", config.id)
			elseif timer <= 0 then
				if TaigaAmbientSoundUtil.checkConditions(config) then
					table.insert(self.readyConfigs, config)
					self.timers[config.id] = math.random(config.minDelay, config.maxDelay)
					TaigaAmbientSoundUtil.debug("[Scheduler] Готов к запуску config=%d", config.id)
				else
					self.timers[config.id] = 60
				end
			end
		end
	end
	return self.readyConfigs
end

------------------------------------------------------------------------------
-- Перезапуск таймера
------------------------------------------------------------------------------
function AmbientSoundScheduler:restartTimer(configId)
	local config = nil
	for _, item in ipairs(self.configs) do
		if item.id == configId then
			config = item
			break
		end
	end
	if config == nil then
		return false
	end
	self.timers[configId] = math.random(config.minDelay, config.maxDelay)
	return true
end

------------------------------------------------------------------------------
-- Принудительный запуск
------------------------------------------------------------------------------
function AmbientSoundScheduler:forceTrigger(configId)
	local config = nil
	for _, item in ipairs(self.configs) do
		if item.id == configId then
			config = item
			break
		end
	end
	if config == nil then
		return false
	end
	-- update() очищает readyConfigs перед обработкой, поэтому запрос хранится отдельно.
	self.forcedConfigs[configId] = true
	return true
end

------------------------------------------------------------------------------
-- Получение оставшегося времени
------------------------------------------------------------------------------
function AmbientSoundScheduler:getRemainingTime(configId)
	return self.timers[configId]
end

------------------------------------------------------------------------------
-- Установка времени
------------------------------------------------------------------------------
function AmbientSoundScheduler:setRemainingTime(configId, seconds)
	self.timers[configId] = math.max(0, seconds)
end

------------------------------------------------------------------------------
-- Очистка
------------------------------------------------------------------------------
function AmbientSoundScheduler:delete()
	self.timers = {}
	self.readyConfigs = {}
	self.forcedConfigs = {}
	self.configs = {}
end