-- @description pmn_Toggle FX: alternar bypass del último FX tocado
-- @author Patricio Maripani Navarro
-- @version 5.1
-- @changelog
--   + Fix: track local (evita variable global)
--   + Alterna el bypass del último FX enfocado/tocado
-- @about
--   Alterna el bypass del último FX que tocaste (el enfocado, con su ventana abierta
--   en la cadena FX de una pista). No requiere tener la pista seleccionada.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_toggle_fx.lua

function toggle_bypass_for_last_focused_floating_track_fx()
  local retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  if retval == 1 and item_number == -1 then
    local track = reaper.CSurf_TrackFromID(track_number, false)
    if track and reaper.ValidatePtr(track, "MediaTrack*") then
      local is_open = reaper.TrackFX_GetOpen(track, fx_number)
      if is_open then
        -- toggle bypass state
        reaper.TrackFX_SetEnabled(track, fx_number, not reaper.TrackFX_GetEnabled(track, fx_number))
      end
    end
  end
end

toggle_bypass_for_last_focused_floating_track_fx()
