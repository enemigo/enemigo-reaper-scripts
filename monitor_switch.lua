-- Toggle SIENNA AND SONARWORKS
-- SET THE POSITION OF THE PLUGINS ON MONITORING CHANNEL
local POS_SONARWORKS = 4 
local POS_SIENNA = 5

local track = reaper.GetMasterTrack()
local cnt = reaper.TrackFX_GetRecCount(track)
if POS_SONARWORKS <= cnt  then

  POS_SONARWORKS = (0x1000000 + (POS_SONARWORKS-1))
  POS_SIENNA = (0x1000000 + (POS_SIENNA-1))

  local enabledSONARWORKS = reaper.TrackFX_GetEnabled(track, POS_SONARWORKS)
  local enabledSIENNA = reaper.TrackFX_GetEnabled(track, POS_SIENNA)
  
  if enabledSONARWORKS then 
    reaper.TrackFX_SetEnabled(track, POS_SONARWORKS, false)
    reaper.TrackFX_SetEnabled(track, POS_SIENNA, true)
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
