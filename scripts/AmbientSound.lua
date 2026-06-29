-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSound.lua
--
-- Объект одного активного окружающего звука.
--
-- Отвечает за:
--   • создание источника;
--   • позиционирование;
--   • проигрывание;
--   • движение;
--   • удаление.
--
-- Не отвечает за:
--   • выбор времени запуска;
--   • XML;
--   • сетевую синхронизацию.
------------------------------------------------------------------------------

AmbientSound = {}


local AmbientSound_mt = Class(
	AmbientSound
)


------------------------------------------------------------------------------
-- Создание объекта
------------------------------------------------------------------------------

--- Создает экземпляр звука.
---@param config table
---@param position table
---@return table
------------------------------------------------------------------------------
function AmbientSound.new(
	config,
	position
)


	local self = setmetatable(
		{},
		AmbientSound_mt
	)


	self.config = config


	self.position = position or {

		x = 0,

		y = 0,

		z = 0

	}


	self.source = nil


	self.isPlaying = false


	self.isFinished = false


	self.moveTimer = 0


	self.lifeTime = 0


	self.targetPosition = nil


	return self

end



------------------------------------------------------------------------------
-- Инициализация
------------------------------------------------------------------------------

--- Подготавливает звук.
---@return boolean
------------------------------------------------------------------------------
function AmbientSound:load()


	if self.config == nil then


		AmbientSoundUtil.error(
			"Попытка создать звук без конфигурации"
		)


		return false

	end



	self.source =
		createSample(
			"AmbientSound_" .. self.config.id
		)


	if self.source == nil then


		AmbientSoundUtil.error(
			"Не удалось создать Sample"
		)


		return false

	end



	setSampleRange(
		self.source,
		self.config.range
	)


	setSampleInnerRange(
		self.source,
		self.config.innerRange
	)


	setSampleVolume(
		self.source,
		self.config.volume
	)


	self:updatePosition()


	return true

end



------------------------------------------------------------------------------
-- Запуск воспроизведения
------------------------------------------------------------------------------

function AmbientSound:play()


	if self.source == nil then

		return false

	end



	local file =
		self:getRandomSoundFile()



	if file == nil then

		AmbientSoundUtil.warning(
			"Нет доступного звукового файла"
		)

		return false

	end



	loadSample(
		self.source,
		file.filename
	)


	playSample(
		self.source
	)


	self.isPlaying = true


	AmbientSoundUtil.debug(
		"Запущен звук ID=%d",
		self.config.id
	)


	return true

end



------------------------------------------------------------------------------
-- Выбор варианта звука
------------------------------------------------------------------------------

function AmbientSound:getRandomSoundFile()


	if self.config.soundFiles == nil then

		return nil

	end



	local id =
		AmbientSoundUtil.randomElement(
			self.config.soundFiles
		)


	if id == nil then

		return nil

	end



	if self.config.fileCache == nil then

		return nil

	end



	return self.config.fileCache[id]

end


-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Обновление позиции источника
------------------------------------------------------------------------------

--- Устанавливает позицию Sample.
------------------------------------------------------------------------------
function AmbientSound:updatePosition()


	if self.source == nil then

		return

	end



	setTranslation(
		self.source,
		self.position.x,
		self.position.y,
		self.position.z
	)

end



------------------------------------------------------------------------------
-- Обновление объекта
------------------------------------------------------------------------------

--- Основной update активного звука.
---@param dt number
------------------------------------------------------------------------------
function AmbientSound:update(dt)


	if self.isFinished then

		return

	end



	self.lifeTime =
		self.lifeTime + dt



	--------------------------------------------------------------------------
	-- Обновление движения
	--------------------------------------------------------------------------

	if self.config.mode == "running"
		or self.config.mode == "fly" then


		self:updateMovement(dt)


	end



	--------------------------------------------------------------------------
	-- Проверка окончания
	--------------------------------------------------------------------------

	if self.isPlaying then


		if not isSamplePlaying(
			self.source
		) then


			self:stop()


		end

	end

end



------------------------------------------------------------------------------
-- Движение источника
------------------------------------------------------------------------------

function AmbientSound:updateMovement(dt)


	self.moveTimer =
		self.moveTimer + dt



	local interval =
		self.config.moveInterval * 1000



	if interval <= 0 then

		return

	end



	if self.moveTimer < interval then

		return

	end



	self.moveTimer = 0



	if self.config.mode == "running" then


		self:createRunningTarget()


	elseif self.config.mode == "fly" then


		self:createFlyTarget()


	end



	self:moveToTarget(dt)

end



------------------------------------------------------------------------------
-- Движение бегущего объекта
------------------------------------------------------------------------------

function AmbientSound:createRunningTarget()


	local angle =
		AmbientSoundUtil.randomFloat(
			0,
			math.pi * 2
		)


	local distance =
		AmbientSoundUtil.randomFloat(
			20,
			60
		)


	self.targetPosition = {


		x =
			self.position.x
			+
			math.cos(angle)
			*
			distance,


		y =
			self.position.y,


		z =
			self.position.z
			+
			math.sin(angle)
			*
			distance


	}

end



------------------------------------------------------------------------------
-- Хаотическое движение насекомых
------------------------------------------------------------------------------

function AmbientSound:createFlyTarget()


	local offset =
		AmbientSoundUtil.randomPointInRadius(
			0,
			0,
			0,
			2
		)



	self.targetPosition = {


		x =
			self.position.x
			+
			offset.x,


		y =
			self.position.y
			+
			AmbientSoundUtil.randomFloat(
				-0.5,
				0.5
			),


		z =
			self.position.z
			+
			offset.z


	}

end



------------------------------------------------------------------------------
-- Перемещение к цели
------------------------------------------------------------------------------

function AmbientSound:moveToTarget(dt)


	if self.targetPosition == nil then

		return

	end



	local speed =
		self.config.moveSpeed



	if speed <= 0 then

		return

	end



	local factor =
		speed
		*
		dt
		/
		1000



	self.position.x =
		self.position.x
		+
		(
			self.targetPosition.x
			-
			self.position.x
		)
		*
		factor



	self.position.y =
		self.position.y
		+
		(
			self.targetPosition.y
			-
			self.position.y
		)
		*
		factor



	self.position.z =
		self.position.z
		+
		(
			self.targetPosition.z
			-
			self.position.z
		)
		*
		factor



	self:updatePosition()

end



------------------------------------------------------------------------------
-- Остановка
------------------------------------------------------------------------------

function AmbientSound:stop()


	if self.source ~= nil then


		stopSample(
			self.source
		)


	end



	self.isPlaying = false


	self.isFinished = true


	AmbientSoundUtil.debug(
		"Завершён звук ID=%d",
		self.config.id
	)

end



------------------------------------------------------------------------------
-- Удаление
------------------------------------------------------------------------------

function AmbientSound:delete()


	if self.source ~= nil then


		delete(
			self.source
		)


		self.source = nil


	end



	self.isFinished = true

end



------------------------------------------------------------------------------
-- Проверка состояния
------------------------------------------------------------------------------

function AmbientSound:isActive()


	return self.isPlaying
		and not self.isFinished

end



------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------

AmbientSoundUtil.info(
	"Модуль AmbientSound загружен"
)