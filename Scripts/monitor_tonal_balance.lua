-- @description pmn_Monitor: mostrar/ocultar Tonal Balance Control
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Mensaje de error si no se encuentra el plugin
-- @about
--   Muestra u oculta la ventana del plugin Tonal Balance Control en la cadena
--   de monitorización del máster.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/monitor_tonal_balance.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGIN = "Tonal Balance"     -- subcadena para localizar el plugin

--------------------------------------------------------------------------------
-- Helpers sobre la cadena de monitorización (rec-FX) del máster
--------------------------------------------------------------------------------
local track = reaper.GetMasterTrack()
local RECFX = 0x1000000 -- prefijo para la cadena de monitorización

local function find_recfx(substr)
  local cnt = reaper.TrackFX_GetRecCount(track)
  local low = substr:lower()
  for i = 0, cnt - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, RECFX + i, "")
    if ok and name and name:lower():find(low, 1, true) then
      return i
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
local idx = find_recfx(PLUGIN)
if not idx then
  reaper.ShowMessageBox(
    string.format("No se encontró el plugin \"%s\" en la cadena de monitorización.", PLUGIN),
    "Monitor Tonal Balance", 0)
  return
end

local fxIdx = RECFX + idx
if reaper.TrackFX_GetOpen(track, fxIdx) == false then
  reaper.TrackFX_Show(track, fxIdx, 1)
else
  reaper.TrackFX_Show(track, fxIdx, 0)
end
