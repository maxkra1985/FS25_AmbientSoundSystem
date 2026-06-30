------------------------------------------------------------------------------
-- AmbientSound.lua
--
-- Один экземпляр воспроизводимого окружающего звука.
--
-- Экземпляр отвечает только за:
--   • загрузку sample;
--   • воспроизведение;
--   • остановку;
--   • движение;
--   • обновление состояния.
--
-- Вопросами Scheduler, XML и Multiplayer занимается
-- AmbientSoundSystem.
------------------------------------------------------------------------------
AmbientSound = {}
local AmbientSound_mt = Class(AmbientSound)

------------------------------------------------------------------------------
-- Создание объекта
------------------------------------------------------------------------------
function AmbientSound.new(customMt)
	local self = setmetatable({}, customMt or AmbientSound_mt)

	-- Конфигурация
	self.config = nil

	-- Runtime
	self.runtimeId = 0

	-- Sample
	self.sample = nil
	self.sampleNode = nil

	-- Положение
	self.position = {x = 0, y = 0, z = 0}

	-- Движение
	self.targetPosition = {x = 0, y = 0, z = 0}
	self.moveTimer = 0
	self.moveInterval = 0
	self.moveSpeed = 0

	-- Состояние
	self.loaded = false
	self.playing = false
	self.finished = false
	return self
end

------------------------------------------------------------------------------
-- Назначение конфигурации
------------------------------------------------------------------------------
function AmbientSound:setConfig(config)
	self.config = config
	self.moveInterval = config.moveInterval or 0
	self.moveSpeed = config.moveSpeed or 0
end

------------------------------------------------------------------------------
-- Установка позиции
------------------------------------------------------------------------------
function AmbientSound:setPosition(position)
	self.position.x = position.x
	self.position.y = position.y
	self.position.z = position.z

	self.targetPosition.x = position.x
	self.targetPosition.y = position.y
	self.targetPosition.z = position.z
end

------------------------------------------------------------------------------
-- Получение позиции
------------------------------------------------------------------------------
function AmbientSound:getPosition()
	return self.position
end

------------------------------------------------------------------------------
-- Загрузка
------------------------------------------------------------------------------
function AmbientSound:load()
	if self.loaded then
		return true
	end

	-- Создание transform node
	self.sampleNode = createTransformGroup("AmbientSound")
	link(getRootNode(), self.sampleNode)
	setTranslation(self.sampleNode, self.position.x, self.position.y, self.position.z)

	-- Создание Sample
	self.sample = AmbientSoundUtil.createSample(self.config)
	if self.sample == nil then
		AmbientSoundUtil.warning( "Не удалось создать Sample.")
		return false
	end

	self.loaded = true
	AmbientSoundUtil.debug("Runtime #%d загружен.", self.runtimeId)
	return true
end

------------------------------------------------------------------------------
-- Запуск воспроизведения
------------------------------------------------------------------------------
function AmbientSound:play()
	if not self.loaded then
		return false
	end
	if self.playing then
		return true
	end
	if self.sample == nil then
		return false
	end

	setTranslation(self.sampleNode, self.position.x, self.position.y, self.position.z)
	playSample(self.sample)
	self.playing = true
	self.finished = false
	AmbientSoundUtil.debug("Runtime #%d запущен.", self.runtimeId)
	return true
end

------------------------------------------------------------------------------
-- Остановка воспроизведения
------------------------------------------------------------------------------
function AmbientSound:stop()
	if not self.playing then
		return
	end

	if self.sample ~= nil then
		stopSample(self.sample)
	end

	self.playing = false
	AmbientSoundUtil.debug("Runtime #%d остановлен.", self.runtimeId)
end

------------------------------------------------------------------------------
-- Обновление
------------------------------------------------------------------------------

function AmbientSound:update(dt)
	if not self.loaded then
		return false
	end

	if self.playing then
		-- Проверяем окончание воспроизведения
		if not isSamplePlaying(self.sample) then
			self.finished = true
			self.playing = false
			return false
		end
	end

	-- Движение источника
	if self.moveInterval > 0 then
		self:updateMovement(dt)
	end
	return true
end

------------------------------------------------------------------------------
-- Обновление движения
------------------------------------------------------------------------------
function AmbientSound:updateMovement(dt)
	self.moveTimer = self.moveTimer + dt
	if self.moveTimer < self.moveInterval * 1000 then
		return
	end
	self.moveTimer = 0

	-- Получаем новую цель движения
	self.targetPosition = AmbientSoundUtil.randomPointInRadius(self.position.x, self.position.y, self.position.z, self.config.distancePlayer or 1.5)

	-- Перемещаемся
	local x, y, z = AmbientSoundUtil.moveTowards(self.position.x, self.position.y, self.position.z, self.targetPosition.x, self.targetPosition.y, self.targetPosition.z, self.moveSpeed)

	self.position.x = x
	self.position.y = y
	self.position.z = z

	setTranslation(self.sampleNode, x, y, z)
end

------------------------------------------------------------------------------
-- Проверка движения
------------------------------------------------------------------------------
function AmbientSound:isMoving()
	return self.moveInterval > 0
end

------------------------------------------------------------------------------
-- Проверка завершения воспроизведения
------------------------------------------------------------------------------
function AmbientSound:isFinished()
	return self.finished
end

------------------------------------------------------------------------------
-- Изменение позиции
------------------------------------------------------------------------------
function AmbientSound:setWorldPosition(x, y, z)
	self.position.x = x
	self.position.y = y
	self.position.z = z
	if self.sampleNode ~= nil then
		setTranslation(self.sampleNode, x, y, z)
	end
end

------------------------------------------------------------------------------
-- Получение позиции
------------------------------------------------------------------------------
function AmbientSound:getWorldPosition()
	return self.position.x, self.position.y, self.position.z
end

------------------------------------------------------------------------------
-- Изменение целевой позиции
------------------------------------------------------------------------------
function AmbientSound:setTargetPosition(x, y, z)
	self.targetPosition.x = x
	self.targetPosition.y = y
	self.targetPosition.z = z
end

------------------------------------------------------------------------------
-- Освобождение ресурсов
------------------------------------------------------------------------------
function AmbientSound:delete()
	-- Остановка воспроизведения
	self:stop()

	-- Удаление Sample
	if self.sample ~= nil then
		delete(self.sample)
		self.sample = nil
	end

	-- Удаление TransformGroup
	if self.sampleNode ~= nil then
		delete(self.sampleNode)
		self.sampleNode = nil
	end

	self.loaded = false
	self.finished = true
	AmbientSoundUtil.debug("Runtime #%d удалён.", self.runtimeId)
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSound:printDebug()
	AmbientSoundUtil.debug("Runtime=%d  Config=%d  Loaded=%s  Playing=%s", self.runtimeId, self.config ~= nil and self.config.id or -1, tostring(self.loaded), tostring(self.playing))
end