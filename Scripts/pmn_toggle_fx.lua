-- @description pmn_Toggle FX: toggle bypass de todos los FX de la pista enfocada
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Primer disparo: usa el FX enfocado (GetFocusedFX) para hallar la pista y hace toggle de bypass de todos sus FX
--   + Ignora los FX offline
-- @about
--   Cuando tienes abierta la ventana de un FX, este script hace toggle de bypass de TODOS
--   los FX de esa pista (los activos se apagan, los inactivos se encienden).
--   Los FX marcados como offline se ignoran (no se tocan).
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_toggle_fx.lua

local function get_focused_track()
  local retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  if retval ~= 1 then
    return nil, "No hay ningún FX enfocado.\nAbre la ventana de un FX de la pista."
  end
  if item_number ~= -1 then
    return nil, "El FX enfocado es de un ítem, no de una pista."
  end

  local track
  if track_number == 0 then
    track = reaper.GetMasterTrack()
  else
    track = reaper.GetTrack(0, track_number - 1)
  end

  if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
    return nil, "No se pudo obtener la pista del FX enfocado."
  end
  return track
end

local function main()
  local track, err = get_focused_track()
  if not track then
    reaper.ShowMessageBox(err, "Toggle FX", 0)
    return
  end

  local n = reaper.TrackFX_GetCount(track)
  if n == 0 then
    reaper.ShowMessageBox("La pista no tiene FX.", "Toggle FX", 0)
    return
  end

  local toggled = 0
  local skipped = 0
  for i = 0, n - 1 do
    if reaper.TrackFX_GetOffline(track, i) then
      skipped = skipped + 1
    else
      reaper.TrackFX_SetEnabled(track, i, not reaper.TrackFX_GetEnabled(track, i))
      toggled = toggled + 1
    end
  end

  local msg = string.format("Toggle aplicado a %d FX.", toggled)
  if skipped > 0 then
    msg = msg .. string.format("\n%d FX offline ignorados.", skipped)
  end
  reaper.ShowMessageBox(msg, "Toggle FX", 0)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Toggle FX de pista enfocada", -1)
