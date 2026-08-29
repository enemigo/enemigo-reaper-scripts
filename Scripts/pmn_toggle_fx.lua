-- @description pmn_Toggle FX: toggle bypass del FX enfocado
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Toggle del FX enfocado (GetFocusedFX), como el original
--   + Sin mensajes al terminar
--   + Validación de punteros y track local
-- @about
--   Cuando tienes un FX enfocado en la cadena de la pista, alterna su bypass
--   (activo<->inactivo). Ignora FX offline.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_toggle_fx.lua

local function get_focused_fx()
  local retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  if retval ~= 1 or item_number ~= -1 then
    return nil, nil
  end

  local track
  if track_number == 0 then
    track = reaper.GetMasterTrack()
  else
    track = reaper.GetTrack(0, track_number - 1)
  end

  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
    return nil, nil
  end

  return track, fx_number
end

local function main()
  local track, fx_number = get_focused_fx()
  if not track or not fx_number then
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
