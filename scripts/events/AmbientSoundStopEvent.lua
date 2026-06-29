-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundStopEvent.lua
--
-- Сетевое событие остановки глобального звука.
--
-- Сервер сообщает клиентам:
--   • какой звук остановить.
--
-- Клиент удаляет активный экземпляр.
------------------------------------------------------------------------------

AmbientSoundStopEvent = {}


local AmbientSoundStopEvent_mt = Class(AmbientSoundStopEvent, Event)

------------------------------------------------------------------------------
-- Регистрация события
------------------------------------------------------------------------------
InitEventClass(AmbientSoundStopEvent, "AmbientSoundStopEvent")

------------------------------------------------------------------------------
-- Создание пустого события
------------------------------------------------------------------------------
function AmbientSoundStopEvent.emptyNew()
	local self = Event.new(AmbientSoundStopEvent_mt)
	return self
end

------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------

---@param soundId number
---@param instanceId number
------------------------------------------------------------------------------
function AmbientSoundStopEvent.new( soundId, instanceId)
	local self = AmbientSoundStopEvent.emptyNew()
	self.soundId = soundId
	self.instanceId = instanceId
	return self
end

------------------------------------------------------------------------------
-- Запись данных
------------------------------------------------------------------------------

function AmbientSoundStopEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId,self.soundId)
	streamWriteInt32(streamId,self.instanceId)
end

------------------------------------------------------------------------------
-- Чтение данных
------------------------------------------------------------------------------

function AmbientSoundStopEvent:readStream(streamId, connection)
	self.soundId = streamReadInt32(streamId)
	self.instanceId = streamReadInt32(streamId)
end

-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Выполнение события
------------------------------------------------------------------------------

function AmbientSoundStopEvent:run()
	if g_ambientSoundSystem == nil then
		AmbientSoundUtil.warning("AmbientSoundSystem отсутствует при остановке звука")
		return
	end

	for index = #g_ambientSoundSystem.activeSounds, 1, -1 do
		local sound = g_ambientSoundSystem.activeSounds[index]
		if sound.config.id == self.soundId then
			sound:stop()
			sound:delete()
			table.remove(g_ambientSoundSystem.activeSounds,index)
			AmbientSoundUtil.debug("Остановлен глобальный звук ID=%d",self.soundId)
			break
		end
	end
end

------------------------------------------------------------------------------
-- Отправка события сервером
------------------------------------------------------------------------------

--- Отправляет команду остановки всем клиентам.
---@param sound table
---@param instanceId number
------------------------------------------------------------------------------
function AmbientSoundStopEvent.sendEvent(sound, instanceId)
	if g_server == nil then
		return
	end
	local event = AmbientSoundStopEvent.new(sound.id, instanceId or 0)
	g_server:broadcastEvent(event,false)
	AmbientSoundUtil.debug("Отправлена остановка глобального звука ID=%d", sound.id)
end

------------------------------------------------------------------------------
-- Завершение загрузки
------------------------------------------------------------------------------

AmbientSoundUtil.info("Модуль AmbientSoundStopEvent загружен")