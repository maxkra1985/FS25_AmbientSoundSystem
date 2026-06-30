------------------------------------------------------------------------------
-- AmbientSoundMoveEvent.lua
-- Сервер -> Клиенты
-- Синхронизация положения движущегося глобального источника звука.
------------------------------------------------------------------------------
AmbientSoundMoveEvent = {}
local AmbientSoundMoveEvent_mt = Class(AmbientSoundMoveEvent, Event)

InitEventClass(AmbientSoundMoveEvent, "AmbientSoundMoveEvent")

------------------------------------------------------------------------------
-- Создание пустого события
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.emptyNew()
	local self = Event.new(AmbientSoundMoveEvent_mt)
	return self
end

------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.new(runtimeId, x, y, z)
	local self = AmbientSoundMoveEvent.emptyNew()
	self.runtimeId = runtimeId
	self.x = x
	self.y = y
	self.z = z
	return self
end

------------------------------------------------------------------------------
-- Запись в поток
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:writeStream(streamId, connection)
	streamWriteUInt16(streamId, self.runtimeId)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
end

------------------------------------------------------------------------------
-- Чтение из потока
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:readStream(streamId, connection)
	self.runtimeId = streamReadUInt16(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self:run(connection)
end

------------------------------------------------------------------------------
-- Выполнение на клиенте
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:run(connection)
	if AmbientSoundUtil.isServer() then
		return
	end
	local system = g_ambientSoundSystem
	if system == nil then
		return
	end
	local runtime = system:getRuntimeSound(self.runtimeId)
	if runtime == nil then
		AmbientSoundUtil.warning("MoveEvent: Runtime #%d не найден.", self.runtimeId)
		return
	end
	runtime:setWorldPosition(self.x, self.y, self.z)
end

------------------------------------------------------------------------------
-- Отправка события
------------------------------------------------------------------------------
function AmbientSoundMoveEvent.sendEvent(runtimeId, x, y, z)
	if not AmbientSoundUtil.isServer() then
		return
	end
	g_server:broadcastEvent(AmbientSoundMoveEvent.new(runtimeId, x, y, z), nil, nil)
end

------------------------------------------------------------------------------
-- Проверка данных
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:validate()
	if self.runtimeId == nil then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundMoveEvent:printDebug()
	AmbientSoundUtil.debug("MoveEvent Runtime=%d Pos=(%.2f %.2f %.2f)", self.runtimeId, self.x, self.y, self.z)
end