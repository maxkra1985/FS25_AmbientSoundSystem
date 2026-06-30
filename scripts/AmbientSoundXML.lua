------------------------------------------------------------------------------
-- AmbientSoundXML.lua
--
-- Загрузка конфигурации Ambient Sound System из XML.
------------------------------------------------------------------------------
AmbientSoundXML = {}

------------------------------------------------------------------------------
-- Загрузка XML
------------------------------------------------------------------------------
function AmbientSoundXML.load(xmlFilename)
	if xmlFilename == nil then
		return nil, nil
	end
	if not fileExists(xmlFilename) then
		AmbientSoundUtil.error("XML файл не найден: %s", tostring(xmlFilename))
		return nil, nil
	end
	local xmlFile = loadXMLFile("AmbientSoundsXML",xmlFilename)
	if xmlFile == nil then
		AmbientSoundUtil.error("Не удалось открыть XML: %s", tostring(xmlFilename))
		return nil, nil
	end

	-- SoundFiles
	local soundFiles = {}
	local index = 0
	while true do
		local key = string.format("ambientSounds.soundFiles.soundFile(%d)", index)
		if not hasXMLProperty(xmlFile, key) then
			break
		end

		local id = getXMLInt(xmlFile, key .. "#id")
		local filename = getXMLString(xmlFile, key .. "#filename")
		if id ~= nil and filename ~= nil then
			soundFiles[id] = filename
			AmbientSoundUtil.debug("SoundFile %d -> %s", id, filename)
		end
		index = index + 1
	end

	-- Sounds
	local configs = {}
	index = 0
	while true do
		local key = string.format("ambientSounds.sounds.sound(%d)", index)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local config = AmbientSoundXML.loadSound(xmlFile, key, soundFiles)
		if config ~= nil then
			config.id = index + 1
			table.insert(configs, config)
		end
		index = index + 1
	end

	delete(xmlFile)
	AmbientSoundUtil.info("Загружено %d описаний звуков.", #configs)
	return soundFiles, configs
end

------------------------------------------------------------------------------
-- Загрузка одного описания звука
------------------------------------------------------------------------------
function AmbientSoundXML.loadSound(xmlFile, key, soundFiles)
	local config = {}
	-- Основные параметры
	config.type = getXMLString(xmlFile, key .. "#type") or "global"
	config.mode = getXMLString(xmlFile, key .. "#mode") or "static"
	config.volume = getXMLFloat(xmlFile, key .. "#volume") or 1
	config.range = getXMLFloat(xmlFile, key .. "#range") or 150
	config.innerRange = getXMLFloat(xmlFile, key .. "#innerRange") or 5
	config.randomRadius = getXMLFloat(xmlFile, key .. "#randomRadius") or 0
	config.distancePlayer = getXMLFloat(xmlFile, key .. "#distancePlayer") or 0
	config.heightOffset = getXMLFloat(xmlFile, key .. "#heightOffset") or 1.6

	-- Время
	config.startHour = getXMLInt(xmlFile, key .. "#startHour") or 0
	config.endHour = getXMLInt(xmlFile, key .. "#endHour") or 24
	config.minDelay = getXMLInt(xmlFile, key .. "#minDelay") or 60
	config.maxDelay = getXMLInt(xmlFile, key .. "#maxDelay") or 120

	-- Движение
	config.moveInterval = getXMLFloat(xmlFile, key .. "#moveInterval") or 0
	config.moveSpeed = getXMLFloat(xmlFile, key .. "#moveSpeed") or 0

	-- Координаты
	local translation = getXMLString(xmlFile, key .. "#translation")
	if translation ~= nil then
		local x, y, z = AmbientSoundUtil.parseVector3(translation)
		config.translation = { x = x, y = y, z = z }
	end

	-- Список файлов
	config.soundFiles = {}
	local fileList = getXMLString(xmlFile, key .. "#soundFiles")

	if fileList ~= nil then
		for _, value in ipairs(AmbientSoundUtil.split(fileList, ",")) do
			local id = tonumber(value)
			if id ~= nil and soundFiles[id] ~= nil then
				table.insert(config.soundFiles, soundFiles[id])
			end
		end
	end

	-- Погода
	config.weather = {}
	local weather = getXMLString(xmlFile, key .. "#weather")
	if weather ~= nil then
		for _, value in ipairs(AmbientSoundUtil.split(weather, " ")) do
			table.insert(config.weather, string.upper(value))
		end
	end

	-- Сезоны
	config.seasons = {}
	local seasons = getXMLString(xmlFile, key .. "#seasons")
	if seasons ~= nil then
		for _, value in ipairs(AmbientSoundUtil.split(seasons, " ")) do
			table.insert(config.seasons, string.upper(value))
		end
	end

	-- Проверка конфигурации
	if #config.soundFiles == 0 then
		AmbientSoundUtil.warning("У звука отсутствуют soundFiles.")
		return nil
	end

	if config.maxDelay < config.minDelay then
		local tmp = config.minDelay
		config.minDelay = config.maxDelay
		config.maxDelay = tmp
	end

	if config.range < config.innerRange then
		config.range = config.innerRange
	end

	return config
end
