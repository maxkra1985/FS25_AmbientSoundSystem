-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundUtil.lua
--
-- Вспомогательные функции системы Ambient Sound.
--
-- Данный модуль не содержит логики воспроизведения звуков.
-- Здесь располагаются только универсальные функции, используемые
-- всеми остальными компонентами системы.
--
-- Автор: Ambient Sound System
------------------------------------------------------------------------------

AmbientSoundUtil = {}

------------------------------------------------------------------------------
-- Константы
------------------------------------------------------------------------------

AmbientSoundUtil.LOG_PREFIX = "[AmbientSound]"

AmbientSoundUtil.LOG_LEVEL_DEBUG   = 0
AmbientSoundUtil.LOG_LEVEL_INFO    = 1
AmbientSoundUtil.LOG_LEVEL_WARNING = 2
AmbientSoundUtil.LOG_LEVEL_ERROR   = 3

------------------------------------------------------------------------------
-- Локальные переменные
------------------------------------------------------------------------------

local debugEnabled = false

------------------------------------------------------------------------------
-- Включение / отключение режима отладки
------------------------------------------------------------------------------

--- Включает или отключает вывод отладочной информации.
---@param state boolean
function AmbientSoundUtil.setDebugEnabled(state)
	debugEnabled = state == true
end

------------------------------------------------------------------------------
--- Возвращает состояние режима отладки.
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundUtil.isDebugEnabled()
	return debugEnabled
end

------------------------------------------------------------------------------
-- Внутреннее логирование
------------------------------------------------------------------------------

local function writeLog(prefix, formatString, ...)

	local text

	if select("#", ...) > 0 then
		text = string.format(formatString, ...)
	else
		text = tostring(formatString)
	end

	Logging.info("%s %s%s",
		AmbientSoundUtil.LOG_PREFIX,
		prefix,
		text
	)

end

------------------------------------------------------------------------------
-- DEBUG
------------------------------------------------------------------------------

--- Выводит отладочное сообщение.
function AmbientSoundUtil.debug(formatString, ...)

	if not debugEnabled then
		return
	end

	writeLog("[DEBUG] ", formatString, ...)

end

------------------------------------------------------------------------------
-- INFO
------------------------------------------------------------------------------

--- Выводит информационное сообщение.
function AmbientSoundUtil.info(formatString, ...)

	writeLog("", formatString, ...)

end

------------------------------------------------------------------------------
-- WARNING
------------------------------------------------------------------------------

--- Выводит предупреждение.
function AmbientSoundUtil.warning(formatString, ...)

	Logging.warning("%s [WARNING] %s",
		AmbientSoundUtil.LOG_PREFIX,
		string.format(formatString, ...)
	)

end

------------------------------------------------------------------------------
-- ERROR
------------------------------------------------------------------------------

--- Выводит сообщение об ошибке.
function AmbientSoundUtil.error(formatString, ...)

	Logging.error("%s [ERROR] %s",
		AmbientSoundUtil.LOG_PREFIX,
		string.format(formatString, ...)
	)

end

------------------------------------------------------------------------------
-- Режим игры
------------------------------------------------------------------------------

--- Возвращает true, если код выполняется на сервере.
---@return boolean
function AmbientSoundUtil.isServer()
	return g_server ~= nil
end

------------------------------------------------------------------------------
--- Возвращает true, если код выполняется на клиенте.
---@return boolean
function AmbientSoundUtil.isClient()
	return g_client ~= nil
end

------------------------------------------------------------------------------
--- Возвращает true для выделенного сервера.
---@return boolean
function AmbientSoundUtil.isDedicatedServer()

	if g_dedicatedServer ~= nil then
		return true
	end

	return false

end

------------------------------------------------------------------------------
--- Возвращает true для одиночной игры.
---@return boolean
function AmbientSoundUtil.isSinglePlayer()

	return AmbientSoundUtil.isServer()
		and AmbientSoundUtil.isClient()

end

------------------------------------------------------------------------------
-- Работа со временем
------------------------------------------------------------------------------

--- Нормализует часы в диапазон 0..23.
---@param hour number
---@return number
function AmbientSoundUtil.wrapHour(hour)

	while hour < 0 do
		hour = hour + 24
	end

	while hour >= 24 do
		hour = hour - 24
	end

	return hour

end

------------------------------------------------------------------------------
--- Проверяет попадание часа в диапазон.
--
-- Поддерживает интервалы через полночь.
--
-- Пример:
--
-- 23 -> 7
--
---@param hour number
---@param startHour number
---@param endHour number
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundUtil.isHourInRange(hour, startHour, endHour)

	hour = AmbientSoundUtil.wrapHour(hour)

	if startHour == endHour then
		return true
	end

	if startHour < endHour then
		return hour >= startHour and hour < endHour
	end

	return hour >= startHour
		or hour < endHour

end

------------------------------------------------------------------------------
--- Преобразует секунды в строку HH:MM:SS.
---@param seconds number
---@return string
------------------------------------------------------------------------------
function AmbientSoundUtil.secondsToText(seconds)

	seconds = math.floor(seconds)

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	return string.format("%02d:%02d:%02d",
		hours,
		minutes,
		secs
	)
end

-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Локальные ссылки Lua функций
------------------------------------------------------------------------------

local floor = math.floor
local random = math.random
local sqrt = math.sqrt

local format = string.format
local upper = string.upper
local lower = string.lower
local sub = string.sub
local find = string.find
local gsub = string.gsub

local insert = table.insert

------------------------------------------------------------------------------
-- Единая система логирования
------------------------------------------------------------------------------

--- Внутренняя функция логирования.
---@param level string
---@param text string
---@param ... any
local function log(level, text, ...)

	if level == AmbientSoundUtil.LOG_LEVEL_DEBUG
		and not debugEnabled then

		return
	end


	local message

	if select("#", ...) > 0 then
		message = format(text, ...)
	else
		message = tostring(text)
	end


	local finalMessage = format(
		"%s [%s] %s",
		AmbientSoundUtil.LOG_PREFIX,
		level,
		message
	)


	if level == AmbientSoundUtil.LOG_LEVEL_ERROR then

		Logging.error(finalMessage)

	elseif level == AmbientSoundUtil.LOG_LEVEL_WARNING then

		Logging.warning(finalMessage)

	else

		Logging.info(finalMessage)

	end

end


------------------------------------------------------------------------------
-- Публичные методы логирования
------------------------------------------------------------------------------

function AmbientSoundUtil.debug(text, ...)

	log(
		AmbientSoundUtil.LOG_LEVEL_DEBUG,
		text,
		...
	)

end


function AmbientSoundUtil.info(text, ...)

	log(
		AmbientSoundUtil.LOG_LEVEL_INFO,
		text,
		...
	)

end


function AmbientSoundUtil.warning(text, ...)

	log(
		AmbientSoundUtil.LOG_LEVEL_WARNING,
		text,
		...
	)

end


function AmbientSoundUtil.error(text, ...)

	log(
		AmbientSoundUtil.LOG_LEVEL_ERROR,
		text,
		...
	)

end


------------------------------------------------------------------------------
-- Работа со строками
------------------------------------------------------------------------------

--- Удаляет пробелы в начале и конце строки.
---@param value string
---@return string
function AmbientSoundUtil.trim(value)

	if value == nil then
		return ""
	end


	return gsub(value, "^%s*(.-)%s*$", "%1")

end


------------------------------------------------------------------------------
--- Разделяет строку по разделителю.
---@param value string
---@param separator string
---@return table
function AmbientSoundUtil.split(value, separator)

	local result = {}

	if value == nil or value == "" then
		return result
	end


	separator = separator or ","


	for item in string.gmatch(
		value,
		"([^" .. separator .. "]+)"
	) do

		insert(
			result,
			AmbientSoundUtil.trim(item)
		)

	end


	return result

end


------------------------------------------------------------------------------
--- Переводит строку в верхний регистр.
---@param value string
---@return string
function AmbientSoundUtil.toUpper(value)

	if value == nil then
		return ""
	end


	return upper(value)

end


------------------------------------------------------------------------------
--- Переводит строку в нижний регистр.
---@param value string
---@return string
function AmbientSoundUtil.toLower(value)

	if value == nil then
		return ""
	end


	return lower(value)

end


------------------------------------------------------------------------------
--- Проверяет начало строки.
---@param value string
---@param search string
---@return boolean
function AmbientSoundUtil.startsWith(value, search)

	if value == nil or search == nil then
		return false
	end


	return sub(
		value,
		1,
		string.len(search)
	) == search

end


------------------------------------------------------------------------------
--- Проверяет конец строки.
---@param value string
---@param search string
---@return boolean
function AmbientSoundUtil.endsWith(value, search)

	if value == nil or search == nil then
		return false
	end


	return sub(
		value,
		-string.len(search)
	) == search

end


------------------------------------------------------------------------------
-- Случайные значения
------------------------------------------------------------------------------

--- Возвращает случайное целое число.
---@param min number
---@param max number
---@return number
function AmbientSoundUtil.randomInt(min, max)

	return random(
		floor(min),
		floor(max)
	)

end


------------------------------------------------------------------------------
--- Возвращает случайное дробное число.
---@param min number
---@param max number
---@return number
function AmbientSoundUtil.randomFloat(min, max)

	return min + random() * (max - min)

end


------------------------------------------------------------------------------
--- Возвращает случайный элемент таблицы.
---@param values table
---@return any
function AmbientSoundUtil.randomElement(values)

	if values == nil or #values == 0 then
		return nil
	end


	return values[
		random(1, #values)
	]

end


------------------------------------------------------------------------------
-- Работа с таблицами
------------------------------------------------------------------------------

--- Возвращает количество элементов таблицы.
---@param value table
---@return number
function AmbientSoundUtil.tableSize(value)

	local count = 0


	if value == nil then
		return 0
	end


	for _ in pairs(value) do

		count = count + 1

	end


	return count

end


------------------------------------------------------------------------------
--- Создает поверхностную копию таблицы.
---@param source table
---@return table
function AmbientSoundUtil.shallowCopy(source)

	local result = {}


	if source == nil then
		return result
	end


	for key, value in pairs(source) do

		result[key] = value

	end


	return result

end


------------------------------------------------------------------------------
--- Очищает таблицу.
---@param value table
function AmbientSoundUtil.clearTable(value)

	if value == nil then
		return
	end


	for key in pairs(value) do

		value[key] = nil

	end

end


-- ЧАСТЬ 3
------------------------------------------------------------------------------
-- Работа с координатами
------------------------------------------------------------------------------

--- Разбирает строку координат X Y Z.
--
-- Пример:
--
-- "100 50 -200"
--
-- возвращает:
--
-- { x = 100, y = 50, z = -200 }
--
---@param value string
---@return table|nil
------------------------------------------------------------------------------
function AmbientSoundUtil.parseTranslation(value)

	if value == nil then
		return nil
	end


	local values = AmbientSoundUtil.split(
		value,
		" "
	)


	if #values < 3 then

		AmbientSoundUtil.warning(
			"Неверный формат координат: %s",
			tostring(value)
		)

		return nil

	end


	return {

		x = tonumber(values[1]) or 0,

		y = tonumber(values[2]) or 0,

		z = tonumber(values[3]) or 0

	}

end


------------------------------------------------------------------------------
--- Создает случайную точку вокруг позиции.
--
-- Используется для:
--  • случайного смещения статических звуков;
--  • появления источников вокруг игрока.
--
---@param x number
---@param y number
---@param z number
---@param radius number
---@return table
------------------------------------------------------------------------------
function AmbientSoundUtil.randomPointInRadius(
	x,
	y,
	z,
	radius
)

	local angle = AmbientSoundUtil.randomFloat(
		0,
		math.pi * 2
	)


	local distance = AmbientSoundUtil.randomFloat(
		0,
		radius
	)


	return {

		x = x + math.cos(angle) * distance,

		y = y,

		z = z + math.sin(angle) * distance

	}

end


------------------------------------------------------------------------------
-- Расстояние между точками
------------------------------------------------------------------------------

--- Возвращает двумерное расстояние.
---@param a table
---@param b table
---@return number
------------------------------------------------------------------------------
function AmbientSoundUtil.distance2D(a, b)

	if a == nil or b == nil then
		return 0
	end


	local dx = a.x - b.x

	local dz = a.z - b.z


	return sqrt(
		dx * dx +
		dz * dz
	)

end


------------------------------------------------------------------------------
--- Возвращает трехмерное расстояние.
---@param a table
---@param b table
---@return number
------------------------------------------------------------------------------
function AmbientSoundUtil.distance3D(a, b)

	if a == nil or b == nil then
		return 0
	end


	local dx = a.x - b.x

	local dy = a.y - b.y

	local dz = a.z - b.z


	return sqrt(
		dx * dx +
		dy * dy +
		dz * dz
	)

end


------------------------------------------------------------------------------
-- Математика
------------------------------------------------------------------------------

--- Ограничивает значение диапазоном.
---@param value number
---@param min number
---@param max number
---@return number
------------------------------------------------------------------------------
function AmbientSoundUtil.clamp(
	value,
	min,
	max
)

	if value < min then

		return min

	elseif value > max then

		return max

	end


	return value

end


------------------------------------------------------------------------------
--- Округляет число.
---@param value number
---@param decimals number
---@return number
------------------------------------------------------------------------------
function AmbientSoundUtil.round(
	value,
	decimals
)

	decimals = decimals or 0


	local multiplier = 10 ^ decimals


	return floor(
		value * multiplier + 0.5
	) / multiplier

end


------------------------------------------------------------------------------
-- Работа с объектами
------------------------------------------------------------------------------

--- Безопасное удаление объекта.
--
-- Используется для:
--  • Sound;
--  • Event;
--  • временных объектов.
--
---@param object any
------------------------------------------------------------------------------
function AmbientSoundUtil.deleteObject(object)

	if object == nil then
		return
	end


	if object.delete ~= nil then

		object:delete()

	end

end


------------------------------------------------------------------------------
-- Общие функции
------------------------------------------------------------------------------

--- Возвращает значение по умолчанию.
---@param value any
---@param default any
---@return any
------------------------------------------------------------------------------
function AmbientSoundUtil.defaultValue(
	value,
	default
)

	if value == nil then

		return default

	end


	return value

end


------------------------------------------------------------------------------
--- Проверяет существование значения в таблице.
---@param tableValue table
---@param searchValue any
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundUtil.contains(
	tableValue,
	searchValue
)

	if tableValue == nil then

		return false

	end


	for _, value in pairs(tableValue) do

		if value == searchValue then

			return true

		end

	end


	return false

end


------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------

AmbientSoundUtil.info(
	"Модуль AmbientSoundUtil загружен"
)