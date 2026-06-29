-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundScheduler.lua
--
-- Планировщик окружающих звуков.
--
-- Отвечает за:
--   • проверку времени;
--   • проверку сезонов;
--   • проверку погоды;
--   • генерацию следующего запуска;
--   • выдачу готовых звуков системе.
--
-- Не отвечает за:
--   • создание SoundSource;
--   • воспроизведение;
--   • сетевую синхронизацию.
------------------------------------------------------------------------------

AmbientSoundScheduler = {}


local AmbientSoundScheduler_mt = Class(
	AmbientSoundScheduler
)


------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------

--- Создает планировщик.
---@param sounds table
---@return table
------------------------------------------------------------------------------
function AmbientSoundScheduler.new(sounds)


	local self = setmetatable(
		{},
		AmbientSoundScheduler_mt
	)


	self.sounds = sounds or {}


	self.lastUpdate = 0


	self.updateInterval = 1000


	return self

end



------------------------------------------------------------------------------
-- Удаление
------------------------------------------------------------------------------

function AmbientSoundScheduler:delete()

	self.sounds = {}

end



------------------------------------------------------------------------------
-- Основное обновление
------------------------------------------------------------------------------

--- Проверяет готовые звуки.
--
-- Возвращает массив звуков,
-- которые можно запускать.
--
---@param dt number
---@return table
------------------------------------------------------------------------------
function AmbientSoundScheduler:update(dt)


	self.lastUpdate =
		self.lastUpdate + dt


	if self.lastUpdate < self.updateInterval then

		return {}

	end


	self.lastUpdate = 0


	local result = {}


	local currentTime =
		AmbientSoundScheduler.getGameTime()


	for _, sound in ipairs(self.sounds) do


		if self:canPlay(sound, currentTime) then


			table.insert(
				result,
				sound
			)


			self:updateNextPlayTime(
				sound
			)


		end


	end


	return result

end



------------------------------------------------------------------------------
-- Проверка возможности запуска
------------------------------------------------------------------------------

--- Проверяет все условия звука.
---@param sound table
---@param gameTime number
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundScheduler:canPlay(
	sound,
	gameTime
)


	if sound == nil then

		return false

	end


	if sound.runtime == nil then

		return false

	end



	--------------------------------------------------------------------------
	-- Проверка задержки
	--------------------------------------------------------------------------

	if sound.runtime.nextPlayTime > g_time then

		return false

	end



	--------------------------------------------------------------------------
	-- Проверка времени суток
	--------------------------------------------------------------------------

	if not AmbientSoundUtil.isHourInRange(
		gameTime,
		sound.startHour,
		sound.endHour
	) then

		return false

	end



	--------------------------------------------------------------------------
	-- Проверка сезона
	--------------------------------------------------------------------------

	if not self:isSeasonAllowed(sound) then

		return false

	end



	--------------------------------------------------------------------------
	-- Проверка погоды
	--------------------------------------------------------------------------

	if not self:isWeatherAllowed(sound) then

		return false

	end



	return true

end



------------------------------------------------------------------------------
-- Установка следующего запуска
------------------------------------------------------------------------------

function AmbientSoundScheduler:updateNextPlayTime(
	sound
)


	local delay =
		AmbientSoundUtil.randomFloat(
			sound.minDelay,
			sound.maxDelay
		)


	sound.runtime.nextPlayTime =
		g_time + delay * 1000



	AmbientSoundUtil.debug(
		"Следующий запуск звука %d через %d секунд",
		sound.id,
		math.floor(delay)
	)

end


-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Получение игрового времени
------------------------------------------------------------------------------

--- Возвращает текущий игровой час.
--
-- FS25 хранит время в минутах игрового времени.
--
---@return number
------------------------------------------------------------------------------
function AmbientSoundScheduler.getGameTime()

	if g_currentMission == nil then

		return 0

	end


	local environment =
		g_currentMission.environment


	if environment == nil then

		return 0

	end


	return environment.currentHour

end



------------------------------------------------------------------------------
-- Проверка сезона
------------------------------------------------------------------------------

--- Проверяет доступность звука в текущий сезон.
---@param sound table
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundScheduler:isSeasonAllowed(sound)


	if sound.seasons == nil
		or #sound.seasons == 0 then

		return true

	end



	if g_currentMission == nil then

		return false

	end



	local environment =
		g_currentMission.environment


	if environment == nil then

		return false

	end



	local season =
		environment.currentSeason



	local seasonName =
		AmbientSoundScheduler.getSeasonName(
			season
		)


	return AmbientSoundUtil.contains(
		sound.seasons,
		seasonName
	)

end



------------------------------------------------------------------------------
-- Получение названия сезона
------------------------------------------------------------------------------

--- Преобразует индекс сезона в текст.
---@param season number
---@return string
------------------------------------------------------------------------------
function AmbientSoundScheduler.getSeasonName(
	season
)

	if season == 1 then

		return "SPRING"

	elseif season == 2 then

		return "SUMMER"

	elseif season == 3 then

		return "AUTUMN"

	elseif season == 4 then

		return "WINTER"

	end


	return "UNKNOWN"

end



------------------------------------------------------------------------------
-- Проверка погоды
------------------------------------------------------------------------------

--- Проверяет возможность запуска при текущей погоде.
---@param sound table
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundScheduler:isWeatherAllowed(sound)


	if sound.weather == nil
		or #sound.weather == 0 then

		return true

	end



	local weather =
		AmbientSoundScheduler.getWeatherName()



	return AmbientSoundUtil.contains(
		sound.weather,
		weather
	)

end



------------------------------------------------------------------------------
-- Получение текущей погоды
------------------------------------------------------------------------------

--- Возвращает название текущей погоды.
---@return string
------------------------------------------------------------------------------
function AmbientSoundScheduler.getWeatherName()


	if g_currentMission == nil then

		return "UNKNOWN"

	end



	local weather =
		g_currentMission.environment



	if weather == nil then

		return "UNKNOWN"

	end



	--------------------------------------------------------------------------
	-- FS25 может возвращать разные состояния.
	-- Здесь сделан простой слой абстракции.
	--------------------------------------------------------------------------

	if weather.isRaining then

		return "RAIN"

	end



	if weather.isSun then

		return "SUN"

	end



	return "CLOUDY"

end



------------------------------------------------------------------------------
-- Принудительный сброс таймеров
------------------------------------------------------------------------------

--- Сбрасывает время следующего запуска.
--
-- Используется после загрузки карты.
--
------------------------------------------------------------------------------
function AmbientSoundScheduler:reset()


	for _, sound in ipairs(self.sounds) do


		if sound.runtime ~= nil then


			sound.runtime.nextPlayTime =
				g_time +
				AmbientSoundUtil.randomFloat(
					sound.minDelay,
					sound.maxDelay
				)
				*
				1000


		end


	end


	AmbientSoundUtil.debug(
		"Таймеры AmbientSound сброшены"
	)

end



------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------

AmbientSoundUtil.info(
	"Модуль AmbientSoundScheduler загружен"
)