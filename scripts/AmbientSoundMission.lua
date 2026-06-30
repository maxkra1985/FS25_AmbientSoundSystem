------------------------------------------------------------------------------
-- AmbientSoundMission.lua
--
-- Интеграция Ambient Sound System в Mission00.
--
-- Данный файл автоматически:
--   • создаёт систему;
--   • загружает XML;
--   • обновляет систему каждый кадр;
--   • освобождает ресурсы.
------------------------------------------------------------------------------
AmbientSoundMission = {}

------------------------------------------------------------------------------
-- Загрузка миссии завершена
------------------------------------------------------------------------------
function AmbientSoundMission.loadMissionFinished(mission)
	if g_ambientSoundSystem ~= nil then
		return
	end
	AmbientSoundUtil.info("Инициализация Ambient Sound System...")
	g_ambientSoundSystem = AmbientSoundSystem.new()
	local xmlFilename = Utils.getFilename("ambientSounds.xml", g_currentModDirectory)
	local success = g_ambientSoundSystem:initialize(xmlFilename)
	if success then
		AmbientSoundUtil.info("Ambient Sound System успешно запущена.")
	else
		AmbientSoundUtil.error("Не удалось инициализировать Ambient Sound System.")
		g_ambientSoundSystem = nil
	end
end

------------------------------------------------------------------------------
-- Обновление Mission
------------------------------------------------------------------------------
function AmbientSoundMission.update(mission, dt)
	if g_ambientSoundSystem == nil then
		return
	end
	if not g_ambientSoundSystem:isEnabled() then
		return
	end
	g_ambientSoundSystem:update(dt)
end

------------------------------------------------------------------------------
-- Завершение миссии
------------------------------------------------------------------------------
function AmbientSoundMission.delete(mission)
	if g_ambientSoundSystem == nil then
		return
	end
	g_ambientSoundSystem:delete()
	g_ambientSoundSystem = nil
end

------------------------------------------------------------------------------
-- Регистрация в Mission00
------------------------------------------------------------------------------
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, AmbientSoundMission.loadMissionFinished)
Mission00.update = Utils.appendedFunction(Mission00.update, AmbientSoundMission.update)
Mission00.delete = Utils.appendedFunction(Mission00.delete, AmbientSoundMission.delete)
