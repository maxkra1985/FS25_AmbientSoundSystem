------------------------------------------------------------------------------
-- AmbientSoundMoveEvent.lua
--
-- Сетевое событие перемещения глобального звука.
--
-- Используется для:
--   • running
--   • fly
--
-- Сервер отправляет новую позицию.
-- Клиенты обновляют источник.
------------------------------------------------------------------------------
AmbientSoundMoveEvent = {}

local AmbientSoundMoveEvent_mt = Class(AmbientSoundMoveEvent, Event)

------------------------------------------------------------------------------
-- Регистрация
------------------------------------------------------------------------------
InitEventClass(AmbientSoundMoveEvent, "AmbientSoundMoveEvent")

------------------------------------------------------------------------------
-- Создание
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.emptyNew()
	local self = Event.new(AmbientSoundMoveEvent_mt)
	return self
end

------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------

---@param soundId number
---@param position table
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.new(soundId, position)
	local self = AmbientSoundMoveEvent.emptyNew()
	self.soundId = soundId
	self.position = {
		x = position.x,
		y = position.y,
		z = position.z
	}
	return self
end

------------------------------------------------------------------------------
-- Запись
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.soundId)
	streamWriteFloat32(streamId, self.position.x)
	streamWriteFloat32(streamId, self.position.y)
	streamWriteFloat32(streamId,self.position.z)
end

------------------------------------------------------------------------------
-- Чтение
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:readStream(streamId,connection)
	self.soundId = streamReadInt32(streamId)
	self.position = {
		x = streamReadFloat32(streamId),
		y = streamReadFloat32(streamId),
		z = streamReadFloat32(streamId)
	}
end


------------------------------------------------------------------------------
-- Выполнение события
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:run()
	if g_ambientSoundSystem == nil then
		AmbientSoundUtil.warning("AmbientSoundSystem отсутствует при перемещении")
		return
	end
	for _, sound in ipairs(g_ambientSoundSystem.activeSounds) do
		if sound.config.id == self.soundId then
			sound.position.x = self.position.x
			sound.position.y = self.position.y
			sound.position.z = self.position.z
			sound:updatePosition()
			AmbientSoundUtil.debug("Перемещён звук ID=%d", self.soundId)
			break
		end
	end
end

------------------------------------------------------------------------------
-- Отправка события перемещения
------------------------------------------------------------------------------

--- Отправляется сервером.
---@param sound table
---@param position table
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.sendEvent(sound, position)
	if g_server == nil then
		return
	end
	local event = AmbientSoundMoveEvent.new(sound.config.id, position)
	g_server:broadcastEvent(event, false)
end

------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------
AmbientSoundUtil.info("Модуль AmbientSoundMoveEvent загружен")