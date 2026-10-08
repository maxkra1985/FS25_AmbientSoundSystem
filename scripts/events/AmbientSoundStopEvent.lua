------------------------------------------------------------------------------
-- AmbientSoundStopEvent.lua
-- Сервер -> Клиенты
-- Остановка и удаление глобального экземпляра звука.
------------------------------------------------------------------------------
AmbientSoundStopEvent = {}
local AmbientSoundStopEvent_mt = Class(AmbientSoundStopEvent, Event)

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
function AmbientSoundStopEvent.new(runtimeId)
	local self = AmbientSoundStopEvent.emptyNew()
	self.runtimeId = runtimeId
	return self
end

------------------------------------------------------------------------------
-- Запись в поток
------------------------------------------------------------------------------
function AmbientSoundStopEvent:writeStream(streamId, connection)
	streamWriteUInt16(streamId, self.runtimeId)
end

------------------------------------------------------------------------------
-- Чтение из потока
------------------------------------------------------------------------------
function AmbientSoundStopEvent:readStream(streamId, connection)
	self.runtimeId = streamReadUInt16(streamId)
	self:run(connection)
end

------------------------------------------------------------------------------
-- Выполнение на клиенте
------------------------------------------------------------------------------
function AmbientSoundStopEvent:run(connection)
	if TaigaAmbientSoundUtil.isServer() then
		return
	end
	local system = g_ambientSoundSystem
	if system == nil then
		return
	end
	local runtime = system:getRuntimeSound(self.runtimeId)
	if runtime == nil then
		return
	end
	-- На клиенте событие удаляет только global, local имеет отдельные ID.
	system:removeRuntimeSound(self.runtimeId)
	TaigaAmbientSoundUtil.debug("Удалён Runtime #%d", self.runtimeId)
end

------------------------------------------------------------------------------
-- Отправка события
------------------------------------------------------------------------------
function AmbientSoundStopEvent.sendEvent(runtimeId)
	if not TaigaAmbientSoundUtil.isServer() then
		return
	end
	g_server:broadcastEvent(AmbientSoundStopEvent.new(runtimeId), nil, nil)
end

------------------------------------------------------------------------------
-- Проверка данных
------------------------------------------------------------------------------
function AmbientSoundStopEvent:validate()
	if self.runtimeId == nil then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundStopEvent:printDebug()
	TaigaAmbientSoundUtil.debug("StopEvent Runtime=%d", self.runtimeId)
end