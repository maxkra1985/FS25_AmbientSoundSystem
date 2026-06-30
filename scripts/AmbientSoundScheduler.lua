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
	AmbientSoundUtil.info("[AmbientSoundScheduler.new] self.configs: %s", tostring(self.configs))
	self.timers = {}
	self.readyConfigs = {}
	return self
end

------------------------------------------------------------------------------
-- Инициализация таймеров
------------------------------------------------------------------------------
function AmbientSoundScheduler:reset()
	self.timers = {}
	self.readyConfigs = {}
	for _, config in ipairs(self.configs) do
		self.timers[config.id] = math.random(config.minDelay, config.maxDelay)
	end
	AmbientSoundUtil.info("[AmbientSoundScheduler.reset] self.timers: %s", tostring(self.timers))
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
			if timer <= 0 then
				if AmbientSoundUtil.checkConditions(config) then
					table.insert(self.readyConfigs, config)
					self.timers[config.id] = math.random(config.minDelay, config.maxDelay)
				else
					self.timers[config.id] = 60
				end
			end
		end
	end
	AmbientSoundUtil.info("[AmbientSoundScheduler.update] self.configs: %s", tostring(self.configs))
	AmbientSoundUtil.info("[AmbientSoundScheduler.update] self.readyConfigs: %s", tostring(self.readyConfigs))
	AmbientSoundUtil.info("[AmbientSoundScheduler.update] self.timers: %s", tostring(self.timers))
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
	table.insert(self.readyConfigs, config)
	self:restartTimer(configId)
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
	self.configs = {}
end