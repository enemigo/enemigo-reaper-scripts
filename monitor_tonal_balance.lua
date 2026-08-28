-- @description Monitor: mostrar/ocultar Tonal Balance Control
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Release ReaPack
-- @about
--   Muestra u oculta la ventana del plugin Tonal Balance Control en la cadena de monitorización
--   del canal máster. Ajusta POS_TONAL si cambia el orden.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/monitor_tonal_balance.lua

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
