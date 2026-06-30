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
	Logging.info("[AmbientSoundMission] mission=%s", tostring(mission))
	Logging.info("[AmbientSoundMission] mission.baseDirectory=%s", tostring(mission.baseDirectory))
	Logging.info("[AmbientSoundMission] mission.missionInfo=%s", tostring(mission.missionInfo))
	if mission.missionInfo ~= nil then
		Logging.info("[AmbientSoundMission] mission.missionInfo.baseDirectory=%s", tostring(mission.missionInfo.baseDirectory))
	end
	Logging.info("[AmbientSoundMission] g_currentModDirectory=%s", tostring(g_currentModDirectory))
	AmbientSoundUtil.info("Инициализация Ambient Sound System...")
	g_ambientSoundSystem = AmbientSoundSystem.new()
	local xmlFilename = Utils.getFilename("scripts/AmbientSoundSystem/ambientSounds.xml",mission.baseDirectory)
	Logging.info("[AmbientSoundMission] xmlFilename='%s'", xmlFilename)
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
