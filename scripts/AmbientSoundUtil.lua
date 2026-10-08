------------------------------------------------------------------------------
-- AmbientSoundUtil.lua
--
-- Общие вспомогательные функции.
------------------------------------------------------------------------------
TaigaAmbientSoundUtil = {}

------------------------------------------------------------------------------
-- Настройки
------------------------------------------------------------------------------
TaigaAmbientSoundUtil.DEBUG = true

------------------------------------------------------------------------------
-- Информация
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.info(text, ...)
	Logging.info("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Предупреждение
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.warning(text, ...)
	Logging.warning("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Ошибка
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.error(text, ...)
	Logging.error("[AmbientSound] " ..string.format(text, ...))
end

------------------------------------------------------------------------------
-- Отладка
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.debug(text, ...)
	if not TaigaAmbientSoundUtil.DEBUG then
		return
	end
	Logging.info("[AmbientSound][DEBUG] " ..string.format(text, ...))

end

------------------------------------------------------------------------------
-- Проверка режима
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.isServer()
	return g_server ~= nil
end

------------------------------------------------------------------------------
-- Проверка клиента
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.isClient()
	return g_client ~= nil
end

------------------------------------------------------------------------------
-- Создание пространственного AudioSource.
-- Возвращает Sample и узел источника: удалять необходимо только AudioSource.
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.createSample(config)
    if config == nil or config.soundFiles == nil or #config.soundFiles == 0 then
        return nil, nil
    end

    -- Случайный вариант выбирается из уже разрешённых при загрузке XML путей.
    local filename = config.soundFiles[math.random(#config.soundFiles)]
    local soundNode = createAudioSource(
        "TaigaAmbientSound",
        filename,
        config.range,
        config.innerRange,
        config.volume,
        1
    )
    if soundNode == nil or soundNode == 0 then
        TaigaAmbientSoundUtil.warning("Не удалось создать AudioSource для '%s'", tostring(filename))
        return nil, nil
    end

    local sample = getAudioSourceSample(soundNode)
    if sample == nil or sample == 0 then
        TaigaAmbientSoundUtil.warning("AudioSource не содержит Sample: '%s'", tostring(filename))
        delete(soundNode)
        return nil, nil
    end

    setAudioSourceAutoPlay(soundNode, false)
    if AudioGroup ~= nil and AudioGroup.ENVIRONMENT ~= nil then
        setSampleGroup(sample, AudioGroup.ENVIRONMENT)
    end
    return sample, soundNode
end

------------------------------------------------------------------------------
-- Получение позиции игрока
------------------------------------------------------------------------------

function TaigaAmbientSoundUtil.getPlayerWorldPosition(player)
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
function TaigaAmbientSoundUtil.checkConditions(config)
	if not TaigaAmbientSoundUtil.checkHour(config) then
		return false
	end
	if not TaigaAmbientSoundUtil.checkSeason(config) then
		return false
	end
	if not TaigaAmbientSoundUtil.checkWeather(config) then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Проверка времени суток
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.checkHour(config)
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
function TaigaAmbientSoundUtil.checkSeason(config)
	if config.seasons == nil then
		return true
	end
	if #config.seasons == 0 then
		return true
	end
	local season = TaigaAmbientSoundUtil.getCurrentSeason()
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
function TaigaAmbientSoundUtil.checkWeather(config)
	if config.weather == nil then
		return true
	end
	if #config.weather == 0 then
		return true
	end
	local weather =
		TaigaAmbientSoundUtil.getCurrentWeather()
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
-- Текущий игровой сезон в строковом формате XML (SPRING, SUMMER и т.д.).
-- GIANTS хранит environment.currentSeason как значение перечисления Season.
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.getCurrentSeason()
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    if environment == nil then
        return nil
    end

    local season = environment.currentSeason
    if season == Season.SPRING then
        return "SPRING"
    elseif season == Season.SUMMER then
        return "SUMMER"
    elseif season == Season.AUTUMN then
        return "AUTUMN"
    elseif season == Season.WINTER then
        return "WINTER"
    end
    return nil
end

------------------------------------------------------------------------------
-- Текущая погода в строковом формате XML.
-- Частичную облачность относим к CLOUDY для совместимости с настройками карты.
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.getCurrentWeather()
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    if environment == nil or environment.weather == nil then
        return nil
    end

    local weather = environment.weather
    if not weather:getIsReady() then
        return nil
    end

    local weatherType = weather:getCurrentWeatherType()
    if weatherType == WeatherType.SUN then
        return "SUN"
    elseif weatherType == WeatherType.PARTIALLY_CLOUDY or weatherType == WeatherType.CLOUDY then
        return "CLOUDY"
    elseif weatherType == WeatherType.RAIN then
        return "RAIN"
    elseif weatherType == WeatherType.SNOW then
        return "SNOW"
    elseif weatherType == WeatherType.HAIL then
        return "HAIL"
    elseif weatherType == WeatherType.TWISTER then
        return "TWISTER"
    elseif weatherType == WeatherType.THUNDER then
        return "THUNDER"
    end
    return nil
end

------------------------------------------------------------------------------
-- Случайная точка внутри радиуса
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.randomPointInRadius(x, y, z, radius)
	local angle = math.random() * math.pi * 2
	local distance = math.random() * radius
	return {x = x + math.cos(angle) * distance, y = y, z = z + math.sin(angle) * distance}
end

------------------------------------------------------------------------------
-- Случайная точка на окружности
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.randomPointOnRadius(x, y, z, radius)
	local angle = math.random() * math.pi * 2
	return {x = x + math.cos(angle) * radius, y = y, z = z + math.sin(angle) * radius }
end

------------------------------------------------------------------------------
-- Движение к цели
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.moveTowards(x, y, z, targetX, targetY, targetZ, speed)
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
function TaigaAmbientSoundUtil.parseVector3(value)
	local result = {}
	for token in string.gmatch(value, "%S+") do
		table.insert(result, tonumber(token))
	end
	return result[1] or 0, result[2] or 0, result[3] or 0
end

------------------------------------------------------------------------------
-- Разделение строки
------------------------------------------------------------------------------
function TaigaAmbientSoundUtil.split(str, separator)
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
