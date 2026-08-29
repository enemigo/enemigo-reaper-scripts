-- @description pmn_Toggle FX: toggle bypass del FX enfocado
-- @author Patricio Maripani Navarro
-- @version 2.1
-- @changelog
--   + No requiere pista seleccionada: usa el FX enfocado (GetFocusedFX + CSurf_TrackFromID)
--   + Solo actúa si la ventana del FX está abierta (is_open), como el original
--   + Sin mensajes al terminar
--   + Ignora FX offline
-- @about
--   Alterna el bypass del FX enfocado (el que tiene la ventana abierta en la cadena FX).
--   No necesita tener la pista seleccionada.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_toggle_fx.lua

local function main()
  local retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  if retval ~= 1 or item_number ~= -1 then
    return
  end

  local track = reaper.CSurf_TrackFromID(track_number, false)
  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
    return
  end

  if not reaper.TrackFX_GetOpen(track, fx_number) then
    return
  end

  if reaper.TrackFX_GetOffline(track, fx_number) then
    return
  end

  reaper.TrackFX_SetEnabled(track, fx_number, not reaper.TrackFX_GetEnabled(track, fx_number))
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Toggle FX enfocado", -1)
