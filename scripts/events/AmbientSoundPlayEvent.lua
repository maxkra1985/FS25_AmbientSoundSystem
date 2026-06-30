------------------------------------------------------------------------------
-- AmbientSoundPlayEvent.lua
--
-- Сервер -> Клиенты
--
-- Создание и запуск глобального окружающего звука.
------------------------------------------------------------------------------
AmbientSoundPlayEvent = {}
local AmbientSoundPlayEvent_mt = Class(AmbientSoundPlayEvent, Event)

InitEventClass(AmbientSoundPlayEvent, "AmbientSoundPlayEvent")

------------------------------------------------------------------------------
-- Создание события
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.emptyNew()
	local self = Event.new(AmbientSoundPlayEvent_mt)
	return self
end

------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.new(runtimeId, configId, position)
	local self = AmbientSoundPlayEvent.emptyNew()
	self.runtimeId = runtimeId
	self.configId = configId
	self.x = position.x
	self.y = position.y
	self.z = position.z
	return self
end

------------------------------------------------------------------------------
-- Запись в поток
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:writeStream(streamId, connection)
	streamWriteUInt16(streamId, self.runtimeId)
	streamWriteUInt16(streamId, self.configId)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
end

------------------------------------------------------------------------------
-- Чтение из потока
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:readStream(streamId, connection)
	self.runtimeId = streamReadUInt16(streamId)
	self.configId = streamReadUInt16(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self:run(connection)
end

------------------------------------------------------------------------------
-- Выполнение на клиенте
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:run(connection)
	if AmbientSoundUtil.isServer() then
		return
	end
	local system = g_ambientSoundSystem
	if system == nil then
		return
	end
	local config = system:getConfig(self.configId)
	if config == nil then
		AmbientSoundUtil.warning("PlayEvent: неизвестный configId=%d", self.configId)
		return
	end

	local runtime = AmbientSound.new()
	runtime.runtimeId = self.runtimeId
	runtime:setConfig(config)
	runtime:setPosition({x = self.x, y = self.y, z = self.z})
	if not runtime:load() then
		return
	end

	runtime:play()
	system.activeSounds[self.runtimeId] = runtime
	AmbientSoundUtil.debug("Получен Runtime #%d", self.runtimeId)
end

------------------------------------------------------------------------------
-- Отправка события
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.sendEvent(runtimeId, configId, position)
	if not AmbientSoundUtil.isServer() then
		return
	end
	g_server:broadcastEvent(AmbientSoundPlayEvent.new(runtimeId, configId, position), nil, nil)
end

------------------------------------------------------------------------------
-- Проверка данных
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:validate()
	if self.runtimeId == nil then
		return false
	end
	if self.configId == nil then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:printDebug()
	AmbientSoundUtil.debug("PlayEvent Runtime=%d Config=%d Pos=(%.2f %.2f %.2f)", self.runtimeId, self.configId, self.x, self.y, self.z)
end