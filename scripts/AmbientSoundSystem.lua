-- ЧАСТЬ 1
------------------------------------------------------------------------------
-- AmbientSoundSystem.lua
--
-- Главный менеджер системы окружающих звуков.
--
-- Отвечает за:
--   • инициализацию системы;
--   • загрузку конфигурации;
--   • управление Scheduler;
--   • создание активных звуков;
--   • обновление событий.
--
-- Не отвечает за:
--   • чтение XML напрямую;
--   • движение объектов;
--   • низкоуровневое управление Sample.
------------------------------------------------------------------------------

AmbientSoundSystem = {}


local AmbientSoundSystem_mt = Class(
	AmbientSoundSystem
)



------------------------------------------------------------------------------
-- Конструктор
------------------------------------------------------------------------------

function AmbientSoundSystem.new()


	local self = setmetatable(
		{},
		AmbientSoundSystem_mt
	)


	self.soundFiles = {}


	self.sounds = {}


	self.scheduler = nil


	self.activeSounds = {}


	self.enabled = true


	self.xmlFilename =
		"ambientSounds.xml"



	return self

end



------------------------------------------------------------------------------
-- Инициализация
------------------------------------------------------------------------------

--- Запуск системы.
---@return boolean
------------------------------------------------------------------------------
function AmbientSoundSystem:initialize()


	AmbientSoundUtil.info(
		"Инициализация Ambient Sound System"
	)



	self.soundFiles,
	self.sounds =
		AmbientSoundXML.load(
			self.xmlFilename
		)



	self:prepareSounds()



	self.scheduler =
		AmbientSoundScheduler.new(
			self.sounds
		)



	self.scheduler:reset()



	AmbientSoundUtil.info(
		"Ambient Sound System готов"
	)


	return true

end



------------------------------------------------------------------------------
-- Подготовка конфигурации
------------------------------------------------------------------------------

function AmbientSoundSystem:prepareSounds()


	for _, sound in ipairs(self.sounds) do


		sound.fileCache =
			self.soundFiles



		AmbientSoundUtil.debug(
			"Подготовлен звук ID=%d",
			sound.id
		)


	end


end



------------------------------------------------------------------------------
-- Обновление системы
------------------------------------------------------------------------------

function AmbientSoundSystem:update(dt)


	if not self.enabled then

		return

	end



	self:updateScheduler(dt)


	self:updateActiveSounds(dt)



end



------------------------------------------------------------------------------
-- Обновление Scheduler
------------------------------------------------------------------------------

function AmbientSoundSystem:updateScheduler(dt)


	local readySounds =
		self.scheduler:update(dt)



	for _, config in ipairs(readySounds) do


		self:createSound(
			config
		)


	end


end


-- ЧАСТЬ 2
------------------------------------------------------------------------------
-- Создание активного звука
------------------------------------------------------------------------------

--- Создает экземпляр AmbientSound.
---@param config table
------------------------------------------------------------------------------
function AmbientSoundSystem:createSound(config)


	local position =
		self:getSoundPosition(
			config
		)


	if position == nil then


		AmbientSoundUtil.warning(
			"Не удалось определить позицию звука ID=%d",
			config.id
		)


		return

	end



	local sound =
		AmbientSound.new(
			config,
			position
		)



	if sound:load() then


		sound:play()



		table.insert(
			self.activeSounds,
			sound
		)



		AmbientSoundUtil.debug(
			"Создан активный звук ID=%d",
			config.id
		)


	end

end



------------------------------------------------------------------------------
-- Определение позиции звука
------------------------------------------------------------------------------

--- Возвращает позицию появления звука.
---@param config table
---@return table
------------------------------------------------------------------------------
function AmbientSoundSystem:getSoundPosition(config)


	--------------------------------------------------------------------------
	-- Локальный звук возле игрока
	--------------------------------------------------------------------------

	if config.type == "local" then


		return self:getPlayerSoundPosition(
			config
		)


	end



	--------------------------------------------------------------------------
	-- Статическая глобальная точка
	--------------------------------------------------------------------------

	if config.mode == "static"
		and config.translation ~= nil then



		local position = {


			x = config.translation.x,

			y = config.translation.y,

			z = config.translation.z


		}



		if config.randomRadius > 0 then


			return AmbientSoundUtil.randomPointInRadius(

				position.x,

				position.y,

				position.z,

				config.randomRadius

			)


		end



		return position

	end



	--------------------------------------------------------------------------
	-- Движущийся глобальный объект вокруг игрока
	--------------------------------------------------------------------------

	if config.distancePlayer > 0 then


		return self:getPlayerSoundPosition(
			config
		)


	end



	return config.translation

end



------------------------------------------------------------------------------
-- Получение позиции около игрока
------------------------------------------------------------------------------

function AmbientSoundSystem:getPlayerSoundPosition(
	config
)


	local player =
		self:getRandomPlayer()



	if player == nil then


		return nil

	end



	local x, y, z =
		getWorldTranslation(
			player.rootNode
		)



	local radius =
		config.distancePlayer



	if radius <= 0 then


		radius = 5


	end



	return AmbientSoundUtil.randomPointInRadius(

		x,

		y,

		z,

		radius

	)

end



------------------------------------------------------------------------------
-- Выбор игрока
------------------------------------------------------------------------------

function AmbientSoundSystem:getRandomPlayer()


	if g_currentMission == nil then

		return nil

	end



	local players =
		g_currentMission.playerSystem.players



	if players == nil
		or #players == 0 then


		return nil

	end



	return AmbientSoundUtil.randomElement(
		players
	)

end



------------------------------------------------------------------------------
-- Обновление активных звуков
------------------------------------------------------------------------------

function AmbientSoundSystem:updateActiveSounds(dt)


	for index = #self.activeSounds, 1, -1 do


		local sound =
			self.activeSounds[index]



		sound:update(dt)



		if not sound:isActive() then



			sound:delete()



			table.remove(
				self.activeSounds,
				index
			)


		end


	end


end



------------------------------------------------------------------------------
-- Остановка всех звуков
------------------------------------------------------------------------------

function AmbientSoundSystem:stopAll()


	for _, sound in ipairs(
		self.activeSounds
	) do


		sound:stop()


	end



end



------------------------------------------------------------------------------
-- Удаление системы
------------------------------------------------------------------------------

function AmbientSoundSystem:delete()


	self:stopAll()



	for _, sound in ipairs(
		self.activeSounds
	) do


		sound:delete()


	end



	self.activeSounds = {}



	if self.scheduler ~= nil then


		self.scheduler:delete()


		self.scheduler = nil


	end



	AmbientSoundUtil.info(
		"Ambient Sound System удалён"
	)

end