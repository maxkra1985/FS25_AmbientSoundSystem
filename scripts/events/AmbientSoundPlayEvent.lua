-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundPlayEvent.lua
--
-- Сетевое событие запуска глобального звука.
--
-- Сервер сообщает клиентам:
--   • какой звук;
--   • где появился;
--   • с какой громкостью.
--
-- Клиенты создают локальный экземпляр AmbientSound.
------------------------------------------------------------------------------

AmbientSoundPlayEvent = {}


local AmbientSoundPlayEvent_mt = Class(
	AmbientSoundPlayEvent,
	Event
)



------------------------------------------------------------------------------
-- Регистрация события
------------------------------------------------------------------------------

InitEventClass(
	AmbientSoundPlayEvent,
	"AmbientSoundPlayEvent"
)



------------------------------------------------------------------------------
-- Создание события
------------------------------------------------------------------------------

function AmbientSoundPlayEvent.emptyNew()

	local self = Event.new(
		AmbientSoundPlayEvent_mt
	)


	return self

end



------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------

--- Создает событие.
---@param soundId number
---@param position table
---@param volume number
---@param isMoving boolean
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.new(
	soundId,
	position,
	volume,
	isMoving
)


	local self =
		AmbientSoundPlayEvent.emptyNew()



	self.soundId = soundId



	self.position = position



	self.volume =
		volume or 1



	self.isMoving =
		isMoving == true



	return self

end



------------------------------------------------------------------------------
-- Запись в поток
------------------------------------------------------------------------------

function AmbientSoundPlayEvent:writeStream(
	streamId,
	connection
)


	streamWriteInt32(
		streamId,
		self.soundId
	)


	streamWriteFloat32(
		streamId,
		self.position.x
	)


	streamWriteFloat32(
		streamId,
		self.position.y
	)


	streamWriteFloat32(
		streamId,
		self.position.z
	)


	streamWriteFloat32(
		streamId,
		self.volume
	)


	streamWriteBool(
		streamId,
		self.isMoving
	)


end



------------------------------------------------------------------------------
-- Чтение из потока
------------------------------------------------------------------------------

function AmbientSoundPlayEvent:readStream(
	streamId,
	connection
)


	self.soundId =
		streamReadInt32(
			streamId
		)


	self.position = {


		x =
			streamReadFloat32(
				streamId
			),


		y =
			streamReadFloat32(
				streamId
			),


		z =
			streamReadFloat32(
				streamId
			)


	}



	self.volume =
		streamReadFloat32(
			streamId
		)



	self.isMoving =
		streamReadBool(
			streamId
		)



end


-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Выполнение события
------------------------------------------------------------------------------

function AmbientSoundPlayEvent:run()


	if g_ambientSoundSystem == nil then


		AmbientSoundUtil.warning(
			"AmbientSoundSystem отсутствует при получении события"
		)


		return

	end



	local config = nil



	for _, sound in ipairs(
		g_ambientSoundSystem.sounds
	) do


		if sound.id == self.soundId then


			config = sound


			break


		end


	end



	if config == nil then


		AmbientSoundUtil.warning(
			"Не найден звук ID=%d",
			self.soundId
		)


		return

	end



	--------------------------------------------------------------------------
	-- Создание звука на клиенте
	--------------------------------------------------------------------------

	local sound =
		AmbientSound.new(
			config,
			self.position
		)



	if sound:load() then



		sound:play()



		table.insert(
			g_ambientSoundSystem.activeSounds,
			sound
		)



		AmbientSoundUtil.debug(
			"Получено сетевое событие звука ID=%d",
			self.soundId
		)


	end


end



------------------------------------------------------------------------------
-- Отправка события всем клиентам
------------------------------------------------------------------------------

--- Вызывается сервером.
---@param sound table
---@param position table
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.sendEvent(
	sound,
	position
)


	if g_server == nil then


		return

	end



	local event =
		AmbientSoundPlayEvent.new(

			sound.id,

			position,

			sound.volume,

			sound.mode ~= "static"

		)



	g_server:broadcastEvent(
		event,
		false
	)



	AmbientSoundUtil.debug(
		"Отправлено глобальное событие звука ID=%d",
		sound.id
	)


end



------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------

AmbientSoundUtil.info(
	"Модуль AmbientSoundPlayEvent загружен"
)