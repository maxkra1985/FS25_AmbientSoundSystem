-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundXML.lua
--
-- Загрузчик конфигурации Ambient Sound.
--
-- Отвечает за:
--   • чтение ambientSounds.xml;
--   • загрузку файлов звуков;
--   • преобразование XML в Lua таблицы;
--   • подготовку данных для Scheduler.
--
-- Не отвечает за:
--   • воспроизведение;
--   • сетевую синхронизацию;
--   • движение источников.
------------------------------------------------------------------------------

AmbientSoundXML = {}


------------------------------------------------------------------------------
-- Загрузка XML
------------------------------------------------------------------------------

--- Загружает конфигурацию ambientSounds.xml.
--
-- Возвращает:
-- soundFiles - список файлов
-- sounds     - список описаний звуков
--
---@param filename string
---@return table, table
------------------------------------------------------------------------------
function AmbientSoundXML.load(filename)

	local soundFiles = {}

	local sounds = {}


	if filename == nil then

		AmbientSoundUtil.error(
			"Не указан файл конфигурации AmbientSound"
		)

		return soundFiles, sounds

	end


	local xmlFile = XMLFile.load(
		"ambientSounds",
		filename,
		AmbientSoundXML.xmlSchema
	)


	if xmlFile == nil then

		AmbientSoundUtil.error(
			"Не удалось открыть XML: %s",
			filename
		)

		return soundFiles, sounds

	end


	AmbientSoundXML.loadSoundFiles(
		xmlFile,
		soundFiles
	)


	AmbientSoundXML.loadSounds(
		xmlFile,
		sounds
	)


	xmlFile:delete()


	AmbientSoundUtil.info(
		"Загружено файлов звуков: %d",
		AmbientSoundUtil.tableSize(soundFiles)
	)


	AmbientSoundUtil.info(
		"Загружено описаний звуков: %d",
		AmbientSoundUtil.tableSize(sounds)
	)


	return soundFiles, sounds

end


------------------------------------------------------------------------------
-- Загрузка списка файлов
------------------------------------------------------------------------------

--- Загружает секцию soundFiles.
---@param xmlFile XMLFile
---@param result table
------------------------------------------------------------------------------
function AmbientSoundXML.loadSoundFiles(
	xmlFile,
	result
)


	local index = 0


	while xmlFile:hasProperty(
		string.format(
			"ambientSounds.soundFiles.soundFile(%d)",
			index
		)
	) do


		local key = string.format(
			"ambientSounds.soundFiles.soundFile(%d)",
			index
		)


		local id = xmlFile:getInt(
			key .. "#id"
		)


		local filename = xmlFile:getString(
			key .. "#filename"
		)


		if id ~= nil and filename ~= nil then


			result[id] = {

				id = id,

				filename = filename

			}


		end


		index = index + 1


	end

end


------------------------------------------------------------------------------
-- Загрузка описаний звуков
------------------------------------------------------------------------------

--- Загружает секцию sounds.
---@param xmlFile XMLFile
---@param result table
------------------------------------------------------------------------------
function AmbientSoundXML.loadSounds(
	xmlFile,
	result
)


	local index = 0


	while xmlFile:hasProperty(
		string.format(
			"ambientSounds.sounds.sound(%d)",
			index
		)
	) do


		local key = string.format(
			"ambientSounds.sounds.sound(%d)",
			index
		)


		local sound = AmbientSoundXML.loadSound(
			xmlFile,
			key,
			index
		)


		if sound ~= nil then

			table.insert(
				result,
				sound
			)

		end


		index = index + 1


	end

end


-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Загрузка одного описания звука
------------------------------------------------------------------------------

--- Загружает один элемент sound.
---@param xmlFile XMLFile
---@param key string
---@param index number
---@return table|nil
------------------------------------------------------------------------------
function AmbientSoundXML.loadSound(
	xmlFile,
	key,
	index
)


	local sound = {}


	--------------------------------------------------------------------------
	-- Основные параметры
	--------------------------------------------------------------------------

	sound.id = index + 1


	sound.type =
		AmbientSoundXML.parseType(
			xmlFile:getString(
				key .. "#type"
			)
		)


	sound.mode =
		AmbientSoundXML.parseMode(
			xmlFile:getString(
				key .. "#mode"
			)
		)


	--------------------------------------------------------------------------
	-- Файлы
	--------------------------------------------------------------------------

	sound.soundFiles =
		AmbientSoundXML.parseSoundFiles(
			xmlFile:getString(
				key .. "#soundFiles"
			)
		)


	if #sound.soundFiles == 0 then

		AmbientSoundUtil.warning(
			"Звук %d не содержит файлов",
			sound.id
		)

		return nil

	end


	--------------------------------------------------------------------------
	-- Позиция
	--------------------------------------------------------------------------

	sound.translation =
		AmbientSoundUtil.parseTranslation(
			xmlFile:getString(
				key .. "#translation"
			)
		)


	sound.randomRadius =
		xmlFile:getFloat(
			key .. "#randomRadius",
			0
		)


	--------------------------------------------------------------------------
	-- Дистанция
	--------------------------------------------------------------------------

	sound.range =
		xmlFile:getFloat(
			key .. "#range",
			100
		)


	sound.innerRange =
		xmlFile:getFloat(
			key .. "#innerRange",
			0
		)


	sound.volume =
		xmlFile:getFloat(
			key .. "#volume",
			1
		)


	--------------------------------------------------------------------------
	-- Время
	--------------------------------------------------------------------------

	sound.startHour =
		xmlFile:getFloat(
			key .. "#startHour",
			0
		)


	sound.endHour =
		xmlFile:getFloat(
			key .. "#endHour",
			24
		)


	--------------------------------------------------------------------------
	-- Задержка
	--------------------------------------------------------------------------

	sound.minDelay =
		xmlFile:getFloat(
			key .. "#minDelay",
			60
		)


	sound.maxDelay =
		xmlFile:getFloat(
			key .. "#maxDelay",
			sound.minDelay
		)


	--------------------------------------------------------------------------
	-- Условия
	--------------------------------------------------------------------------

	sound.weather =
		AmbientSoundXML.parseList(
			xmlFile:getString(
				key .. "#wheater"
			)
		)


	sound.seasons =
		AmbientSoundXML.parseList(
			xmlFile:getString(
				key .. "#seasons"
			)
		)


	--------------------------------------------------------------------------
	-- Движение
	--------------------------------------------------------------------------

	sound.distancePlayer =
		xmlFile:getFloat(
			key .. "#distancePlayer",
			0
		)


	sound.moveInterval =
		xmlFile:getFloat(
			key .. "#moveInterval",
			0
		)


	sound.moveSpeed =
		xmlFile:getFloat(
			key .. "#moveSpeed",
			0
		)


	--------------------------------------------------------------------------
	-- Runtime состояние
	--------------------------------------------------------------------------

	sound.runtime = {

		nextPlayTime = 0,

		activeInstances = 0

	}


	return sound

end



------------------------------------------------------------------------------
-- Преобразование списка файлов
------------------------------------------------------------------------------

--- Преобразует:
--
-- "1,2,3"
--
-- в:
--
-- {1,2,3}
--
---@param value string
---@return table
------------------------------------------------------------------------------
function AmbientSoundXML.parseSoundFiles(value)

	local result = {}


	if value == nil then

		return result

	end


	local values =
		AmbientSoundUtil.split(
			value,
			","
		)


	for _, id in ipairs(values) do


		local number = tonumber(id)


		if number ~= nil then

			table.insert(
				result,
				number
			)

		end


	end


	return result

end



------------------------------------------------------------------------------
-- Преобразование списков условий
------------------------------------------------------------------------------

--- Преобразует строку:
--
-- "WINTER SPRING SUMMER"
--
-- в таблицу.
--
---@param value string
---@return table
------------------------------------------------------------------------------
function AmbientSoundXML.parseList(value)
	local result = {}

	if value == nil then
		return result
	end


	local values =
		AmbientSoundUtil.split(
			value,
			" "
		)

	for _, item in ipairs(values) do
		table.insert(
			result,
			AmbientSoundUtil.toUpper(item)
		)
	end
	return result

end



------------------------------------------------------------------------------
-- Тип звука
------------------------------------------------------------------------------

function AmbientSoundXML.parseType(value)
	value =
		AmbientSoundUtil.toLower(
			value
		)

	if value == "local" then
		return "local"
	end

	return "global"
end



------------------------------------------------------------------------------
-- Режим звука
------------------------------------------------------------------------------

function AmbientSoundXML.parseMode(value)


	value =
		AmbientSoundUtil.toLower(
			value
		)


	if value == "running" then
		return "running"
	end


	if value == "fly" then
		return "fly"
	end

	return "static"

end