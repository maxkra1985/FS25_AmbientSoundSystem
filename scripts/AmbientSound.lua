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
-- TaigaAmbientSoundSystem.
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

	-- Индекс выбранного файла. Для global определяется сервером.
	self.soundIndex = nil
	-- Сетевые global на клиенте не рассчитывают движение самостоятельно.
	self.networkControlled = false

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
-- Загрузка 3D-звука: Sample принадлежит AudioSource и движется вместе с ним.
------------------------------------------------------------------------------
function AmbientSound:load(soundIndex)
    if self.loaded then
        return true
    end

    -- Для глобального звука клиент загружает только назначенный сервером файл.
    self.sample, self.sampleNode, self.soundIndex = TaigaAmbientSoundUtil.createSample(self.config, soundIndex)
    if self.sample == nil or self.sampleNode == nil then
        TaigaAmbientSoundUtil.warning("Не удалось создать пространственный звук Runtime #%d", self.runtimeId)
        return false
    end

    link(getRootNode(), self.sampleNode)
    setWorldTranslation(self.sampleNode, self.position.x, self.position.y, self.position.z)

    self.loaded = true
    TaigaAmbientSoundUtil.debug("Runtime #%d загружен (вариант %d).", self.runtimeId, self.soundIndex)
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

	-- Узел AudioSource установлен в мировых координатах при загрузке.
	setWorldTranslation(self.sampleNode, self.position.x, self.position.y, self.position.z)
	playSample(self.sample, 1, 1, 0)
	self.playing = true
	self.finished = false
	TaigaAmbientSoundUtil.debug("Runtime #%d запущен.", self.runtimeId)
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
	TaigaAmbientSoundUtil.debug("Runtime #%d остановлен.", self.runtimeId)
end

------------------------------------------------------------------------------
-- Обновление
------------------------------------------------------------------------------
-- Обновляет воспроизведение и возвращает состояние, а также факт перемещения.
function AmbientSound:update(dt)
    if not self.loaded then
        return false, false
    end

    if self.playing and not isSamplePlaying(self.sample) then
        self.finished = true
        self.playing = false
        return false, false
    end

    -- Клиентские копии global движутся только через MoveEvent от сервера.
    local moved = false
    if self.playing and not self.networkControlled and self.moveInterval > 0 then
        moved = self:updateMovement(dt)
    end
    return true, moved
end

------------------------------------------------------------------------------
-- Обновление движения
------------------------------------------------------------------------------
-- Сдвигает источник с заданным интервалом и возвращает true только при изменении координат.
function AmbientSound:updateMovement(dt)
    local intervalMs = self.moveInterval * 1000
    if intervalMs <= 0 then
        return false
    end

    self.moveTimer = self.moveTimer + dt
    if self.moveTimer < intervalMs then
        return false
    end
    self.moveTimer = self.moveTimer % intervalMs

    -- Сохраняем существующую случайную траекторию, но не отправляем неизменную позицию.
    self.targetPosition = TaigaAmbientSoundUtil.randomPointInRadius(
        self.position.x, self.position.y, self.position.z, self.config.distancePlayer or 1.5
    )
    local x, y, z = TaigaAmbientSoundUtil.moveTowards(
        self.position.x, self.position.y, self.position.z,
        self.targetPosition.x, self.targetPosition.y, self.targetPosition.z,
        self.moveSpeed
    )
    if x == self.position.x and y == self.position.y and z == self.position.z then
        return false
    end

    self:setWorldPosition(x, y, z)
    return true
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
		setWorldTranslation(self.sampleNode, x, y, z)
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

    -- Sample создан внутри AudioSource, отдельно удалять его нельзя.
    if self.sampleNode ~= nil then
        delete(self.sampleNode)
        self.sampleNode = nil
    end
    self.sample = nil

	self.loaded = false
	self.finished = true
	TaigaAmbientSoundUtil.debug("Runtime #%d удалён.", self.runtimeId)
end

------------------------------------------------------------------------------
-- Отладочная информация
------------------------------------------------------------------------------
function AmbientSound:printDebug()
	TaigaAmbientSoundUtil.debug("Runtime=%d  Config=%d  Loaded=%s  Playing=%s", self.runtimeId, self.config ~= nil and self.config.id or -1, tostring(self.loaded), tostring(self.playing))
end