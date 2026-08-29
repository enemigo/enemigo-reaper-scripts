-- @description pmn_Compara FX: A/B switch de la cadena FX de la pista seleccionada
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Primer disparo: guarda el estado de los FX de la pista seleccionada e invierte activos<->inactivos
--   + Segundo disparo: restaura el estado original
--   + Soporta master track (selección de pista 0)
-- @about
--   A/B switch de la cadena FX de la pista seleccionada. Al disparar por primera vez
--   guarda qué FX estaban activos y los invierte (los activos se apagan y viceversa).
--   Al disparar de nuevo, restaura el estado original. Útil para comparar
--   procesado con/sin FX.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_compara_fx.lua

local EXT_SECTION = "enemigo_compara_fx"

local function get_selected_track()
  local count = reaper.CountSelectedTracks(0)
  if count > 0 then
    return reaper.GetSelectedTrack(0, 0)
  end
  return nil
end

local function track_id(track)
  local tn = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  if not tn then return "master" end
  return tostring(math.floor(tn))
end

local function snapshot_track(track)
  local n = reaper.TrackFX_GetCount(track)
  local bits = {}
  for i = 0, n - 1 do
    bits[#bits + 1] = reaper.TrackFX_GetEnabled(track, i) and "1" or "0"
  end
  return table.concat(bits, "")
end

local function apply_snapshot(track, snap)
  for i = 0, #snap - 1 do
    local enabled = snap:sub(i + 1, i + 1) == "1"
    reaper.TrackFX_SetEnabled(track, i, enabled)
  end
end

local function main()
  local track = get_selected_track()
  if not track then
    reaper.ShowMessageBox("Selecciona una pista para comparar sus FX.", "Compara FX", 0)
    return
  end

  local n = reaper.TrackFX_GetCount(track)
  if n == 0 then
    reaper.ShowMessageBox("La pista seleccionada no tiene FX.", "Compara FX", 0)
    return
  end

  local key = "snap_" .. track_id(track)
  local saved = reaper.GetExtState(EXT_SECTION, key)

  if saved ~= "" then
    -- Restaurar estado original
    apply_snapshot(track, saved)
    reaper.SetExtState(EXT_SECTION, key, "", true)
    reaper.ShowMessageBox("Estado original restaurado.", "Compara FX", 0)
  else
    -- Guardar estado actual e invertir
    local snap = snapshot_track(track)
    reaper.SetExtState(EXT_SECTION, key, snap, true)
    for i = 0, n - 1 do
      reaper.TrackFX_SetEnabled(track, i, not reaper.TrackFX_GetEnabled(track, i))
    end
    reaper.ShowMessageBox("FX invertidos (activos<->inactivos). Vuelve a ejecutar para restaurar.", "Compara FX", 0)
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Compara FX A/B", -1)
