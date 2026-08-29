-- @description pmn_Toggle FX: toggle bypass del último FX flotante enfocado
-- @author Patricio Maripani Navarro
-- @version 5.0
-- @changelog
--   + Original restaurado
-- @about
--   Alterna el bypass del último FX flotante enfocado en una pista.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_toggle_fx.lua

function toggle_bypass_for_last_focused_floating_track_fx()
  local retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  if retval == 1 and item_number == -1 then
    track = reaper.CSurf_TrackFromID(track_number, false)
    local is_open = reaper.TrackFX_GetOpen(track, fx_number)
    if is_open then
      -- toggle bypass state
      reaper.TrackFX_SetEnabled(track, fx_number, not reaper.TrackFX_GetEnabled(track, fx_number))
    end
  end
end

toggle_bypass_for_last_focused_floating_track_fx()
