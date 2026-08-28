-- @description Monitor: toggle bypass plugin DIM
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Release ReaPack
-- @about
--   Alterna el bypass del plugin DIM (dim/atenuación) en la cadena de monitorización
--   del canal máster. Ajusta POS_DIM si cambia el orden.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/monotor_dim.lua

-- BYPASS DIM plugin
-- SET THE POSITION OF THE PLUGINS ON MONITORING CHANNEL
local POS_DIM = 1 

local track = reaper.GetMasterTrack()
local cnt = reaper.TrackFX_GetRecCount(track)
if POS_DIM <= cnt  then

  POS_DIM = (0x1000000 + (POS_DIM-1))

  local enabledDIM = reaper.TrackFX_GetEnabled(track, POS_DIM)
  
  if enabledDIM then 
    reaper.TrackFX_SetEnabled(track, POS_DIM, false)
  else
    reaper.TrackFX_SetEnabled(track, POS_DIM, true)

  end

  -- set toolbar highlight
  local self = ({reaper.get_action_context()})[4]
  if enabledDIM then  
    reaper.SetToggleCommandState(0, self, 1)
  else
    reaper.SetToggleCommandState(0, self, 0)
  end
end


reaper.defer(function () end)



