------------------------------------------------------------------------------
-- AmbientSoundUtil.lua
--
-- Общие вспомогательные функции.
------------------------------------------------------------------------------
AmbientSoundUtil = {}

------------------------------------------------------------------------------
-- Настройки
------------------------------------------------------------------------------
AmbientSoundUtil.DEBUG = true

------------------------------------------------------------------------------
-- Информация
------------------------------------------------------------------------------
function AmbientSoundUtil.info(text, ...)
	Logging.info("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Предупреждение
------------------------------------------------------------------------------
function AmbientSoundUtil.warning(text, ...)
	Logging.warning("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Ошибка
------------------------------------------------------------------------------
function AmbientSoundUtil.error(text, ...)
	Logging.error("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Отладка
------------------------------------------------------------------------------
function AmbientSoundUtil.debug(text, ...)
	if not AmbientSoundUtil.DEBUG then
		return
	end
	Logging.info("[AmbientSound][DEBUG] " ..string.format(text, ...))

end

------------------------------------------------------------------------------
-- Проверка режима
------------------------------------------------------------------------------
function AmbientSoundUtil.isServer()
	return g_server ~= nil
end

------------------------------------------------------------------------------
-- Проверка клиента
------------------------------------------------------------------------------
function AmbientSoundUtil.isClient()
	return g_client ~= nil
end

------------------------------------------------------------------------------
-- Создание Sample
------------------------------------------------------------------------------
function AmbientSoundUtil.createSample(config)
	if config == nil then
		return nil
	end
	if config.soundFiles == nil then
		return nil
	end
	if #config.soundFiles == 0 then
		return nil
	end

	-- Случайный файл
	local filename = config.soundFiles[math.random(#config.soundFiles)]
	if filename == nil then
		return nil
	end

	-- Создание Sample
	local sample = createSample("AmbientSound")
	if sample == nil then
		AmbientSoundUtil.warning("Не удалось создать Sample.")
		return nil
	end

	loadSample(sample, filename, false)
	setSampleVolume(sample, config.volume)
	setSampleInnerRange(sample, config.innerRange)
	setSampleOuterRange(sample, config.range)
	return sample
end

------------------------------------------------------------------------------
-- Получение позиции игрока
------------------------------------------------------------------------------

function AmbientSoundUtil.getPlayerWorldPosition(player)
	if player == nil then
		return 0, 0, 0
	end
	local node = nil
	if player.rootNode ~= nil then
		node = player.rootNode
	elseif player.getRootNode ~= nil then
		node = player:getRootNode()
	end
	if node == nil then
		return 0, 0, 0
	end
	return getWorldTranslation(node)
end

------------------------------------------------------------------------------
-- Проверка условий воспроизведения
------------------------------------------------------------------------------
function AmbientSoundUtil.checkConditions(config)
	if not AmbientSoundUtil.checkHour(config) then
		return false
	end
	if not AmbientSoundUtil.checkSeason(config) then
		return false
	end
	if not AmbientSoundUtil.checkWeather(config) then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Проверка времени суток
------------------------------------------------------------------------------
function AmbientSoundUtil.checkHour(config)
	if g_currentMission == nil then
		return true
	end
	local environment = g_currentMission.environment
	if environment == nil then
		return true
	end
	local hour = environment.currentHour
	if hour == nil then
		return true
	end
	local startHour = config.startHour or 0
	local endHour = config.endHour or 24
	if startHour <= endHour then
		return hour >= startHour and hour < endHour
	end
	return hour >= startHour or hour < endHour

end

------------------------------------------------------------------------------
-- Проверка сезона
------------------------------------------------------------------------------
function AmbientSoundUtil.checkSeason(config)
	if config.seasons == nil then
		return true
	end
	if #config.seasons == 0 then
		return true
	end
	local season = AmbientSoundUtil.getCurrentSeason()
	if season == nil then
		return true
	end
	season = string.upper(season)
	for _, value in ipairs(config.seasons) do
		if value == season then
			return true
		end
	end

	return false
end

------------------------------------------------------------------------------
-- Проверка погоды
------------------------------------------------------------------------------
function AmbientSoundUtil.checkWeather(config)
	if config.weather == nil then
		return true
	end
	if #config.weather == 0 then
		return true
	end
	local weather =
		AmbientSoundUtil.getCurrentWeather()
	if weather == nil then
		return true
	end
	weather = string.upper(weather)
	for _, value in ipairs(config.weather) do
		if value == weather then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Получение текущего сезона
------------------------------------------------------------------------------
function AmbientSoundUtil.getCurrentSeason()
	if g_currentMission == nil then
		return nil
	end
	local environment = g_currentMission.environment
	if environment == nil then
		return nil
	end
	if environment.currentSeason ~= nil then
		return tostring(environment.currentSeason)
	end
	if environment.season ~= nil then
		return tostring(environment.season)
	end
	return nil
end

------------------------------------------------------------------------------
-- Получение текущей погоды
------------------------------------------------------------------------------
function AmbientSoundUtil.getCurrentWeather()
	if g_currentMission == nil then
		return nil
	end
	local environment = g_currentMission.environment
	if environment == nil then
		return nil
	end
	if environment.weather ~= nil then
		return tostring(environment.weather)
	end
	if environment.weatherType ~= nil then
		return tostring(environment.weatherType)
	end
	return nil
end

------------------------------------------------------------------------------
-- Случайная точка внутри радиуса
------------------------------------------------------------------------------
function AmbientSoundUtil.randomPointInRadius(x, y, z, radius)
	local angle = math.random() * math.pi * 2
	local distance = math.random() * radius
	return {x = x + math.cos(angle) * distance, y = y, z = z + math.sin(angle) * distance}
end

------------------------------------------------------------------------------
-- Случайная точка на окружности
------------------------------------------------------------------------------
function AmbientSoundUtil.randomPointOnRadius(x, y, z, radius)
	local angle = math.random() * math.pi * 2
	return {x = x + math.cos(angle) * radius, y = y, z = z + math.sin(angle) * radius }
end

------------------------------------------------------------------------------
-- Движение к цели
------------------------------------------------------------------------------
function AmbientSoundUtil.moveTowards(x, y, z, targetX, targetY, targetZ, speed)
	local dx = targetX - x
	local dy = targetY - y
	local dz = targetZ - z
	local distance = MathUtil.vector3Length(dx, dy, dz)

	if distance < 0.001 then
		return targetX, targetY, targetZ
	end
	local step = math.min(speed, distance)
	return x + dx / distance * step, y + dy / distance * step, z + dz / distance * step
end

------------------------------------------------------------------------------
-- Разбор строки "x y z"
------------------------------------------------------------------------------
function AmbientSoundUtil.parseVector3(value)
	local result = {}
	for token in string.gmatch(value, "%S+") do
		table.insert(result, tonumber(token))
	end
	return result[1] or 0, result[2] or 0, result[3] or 0
end

------------------------------------------------------------------------------
-- Разделение строки
------------------------------------------------------------------------------
function AmbientSoundUtil.split(str, separator)
	local result = {}
	separator = separator or ","
	local pattern
	if separator == " " then
		pattern = "%S+"
	else
		pattern = "([^" .. separator .. "]+)"
	end
	for value in string.gmatch(str, pattern) do
		value = value:gsub("^%s+", "")
		value = value:gsub("%s+$", "")
		if value ~= "" then
			table.insert(result, value)
		end
	end
	return result
end
