-- @description Monitor: bypass Sonarworks y Sienna
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Release ReaPack
-- @about
--   Alterna el bypass de los plugins Sonarworks y Sienna de la cadena de monitorización
--   del canal máster. Ajusta las posiciones POS_SONARWORKS / POS_SIENNA si cambia el orden.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/monitor_off.lua

-- BYPASS SIENNA AND SONARWORKS
-- SET THE POSITION OF THE PLUGINS ON MONITORING CHANNEL
local POS_SONARWORKS = 4 
local POS_SIENNA = 5

local track = reaper.GetMasterTrack()
local cnt = reaper.TrackFX_GetRecCount(track)
if POS_SONARWORKS <= cnt  then

  POS_SONARWORKS = (0x1000000 + (POS_SONARWORKS-1))
  POS_SIENNA = (0x1000000 + (POS_SIENNA-1))

  local enabledSONARWORKS = reaper.TrackFX_GetEnabled(track, POS_SONARWORKS)
  
  if enabledSONARWORKS then 
    reaper.TrackFX_SetEnabled(track, POS_SONARWORKS, false)
    reaper.TrackFX_SetEnabled(track, POS_SIENNA, false)
  else
    reaper.TrackFX_SetEnabled(track, POS_SONARWORKS, true)
    reaper.TrackFX_SetEnabled(track, POS_SIENNA, false)

  end

  -- set toolbar highlight
  local self = ({reaper.get_action_context()})[4]
  if enabledSONARWORKS then  
    reaper.SetToggleCommandState(0, self, 1)
  else
    reaper.SetToggleCommandState(0, self, 0)
  end
end


reaper.defer(function () end)
