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
function AmbientSoundPlayEvent.new(runtimeId, configId, soundIndex, position)
	local self = AmbientSoundPlayEvent.emptyNew()
	self.runtimeId = runtimeId
	self.configId = configId
	self.soundIndex = soundIndex
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
	streamWriteUInt16(streamId, self.soundIndex)
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
	self.soundIndex = streamReadUInt16(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self:run(connection)
end

------------------------------------------------------------------------------
-- Выполнение на клиенте
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:run(connection)
	if TaigaAmbientSoundUtil.isServer() then
		return
	end
	local system = g_ambientSoundSystem
	if system == nil then
		return
	end
	local config = system:getConfig(self.configId)
	if config == nil or config.type ~= "global" then
		TaigaAmbientSoundUtil.warning("PlayEvent: неизвестный global configId=%d", self.configId)
		return
	end
	-- Повторные PlayEvent возможны во время первоначальной синхронизации.
	if system:getRuntimeSound(self.runtimeId) ~= nil then
		return
	end
	if self.soundIndex < 1 or self.soundIndex > #config.soundFiles then
		TaigaAmbientSoundUtil.warning("PlayEvent: неверный индекс файла %d для configId=%d", self.soundIndex, self.configId)
		return
	end

	local runtime = AmbientSound.new()
	runtime.runtimeId = self.runtimeId
	runtime:setConfig(config)
	runtime.networkControlled = true
	runtime:setPosition({x = self.x, y = self.y, z = self.z})
	if not runtime:load(self.soundIndex) then
		runtime:delete()
		return
	end
	if not runtime:play() then
		runtime:delete()
		return
	end
	system.activeSounds[self.runtimeId] = runtime
	TaigaAmbientSoundUtil.debug("Получен Runtime #%d", self.runtimeId)
end

------------------------------------------------------------------------------
-- Отправка события
------------------------------------------------------------------------------
function AmbientSoundPlayEvent.sendEvent(runtimeId, configId, soundIndex, position)
	if not TaigaAmbientSoundUtil.isServer() then
		return
	end
	g_server:broadcastEvent(AmbientSoundPlayEvent.new(runtimeId, configId, soundIndex, position), nil, nil)
end

------------------------------------------------------------------------------
-- Проверка данных
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:validate()
	if self.runtimeId == nil then
		return false
	end
	if self.configId == nil or self.soundIndex == nil then
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSoundPlayEvent:printDebug()
	TaigaAmbientSoundUtil.debug("PlayEvent Runtime=%d Config=%d FileIndex=%d Pos=(%.2f %.2f %.2f)", self.runtimeId, self.configId, self.soundIndex, self.x, self.y, self.z)
end