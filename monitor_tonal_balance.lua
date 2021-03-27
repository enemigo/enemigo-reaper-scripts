-- TOGGLE VISIBILITY OF TONAL BALANCE CONTROL
local POS_TONAL = 2
local track = reaper.GetMasterTrack()
POS_TONAL = (0x1000000 + (POS_TONAL-1))


if reaper.TrackFX_GetOpen(track,POS_TONAL) == false then
--reaper.ShowConsoleMsg("if")
reaper.TrackFX_Show(reaper.GetMasterTrack(), POS_TONAL, 1)
else 
--reaper.ShowConsoleMsg("else")
reaper.TrackFX_Show(reaper.GetMasterTrack(), POS_TONAL, 0)
end 
