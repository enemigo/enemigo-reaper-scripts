-- @description pmn_Monitor: toggle bypass plugin DIM
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
-- @about
--   Alterna el bypass del plugin DIM (dim/atenuación) en la cadena de monitorización del máster.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/monotor_dim.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGIN = "Dim"               -- subcadena para localizar el plugin
local EXT_SECTION = "enemigo_monitor"
local EXT_KEY = "dim_state"

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

local function set_toolbar_state(state)
  local _, _, _, cmd = reaper.get_action_context()
  if cmd then
    reaper.SetToggleCommandState(0, cmd, state and 1 or 0)
    reaper.RefreshToolbar2(cmd, 0)
  end
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
local idx = find_recfx(PLUGIN)
if not idx then
  reaper.ShowMessageBox(
    string.format("No se encontró el plugin \"%s\" en la cadena de monitorización.", PLUGIN),
    "Monitor dim", 0)
  return
end

local state = reaper.TrackFX_GetEnabled(track, RECFX + idx) == 0
reaper.TrackFX_SetEnabled(track, RECFX + idx, state)

reaper.SetExtState(EXT_SECTION, EXT_KEY, state and "1" or "0", true)
set_toolbar_state(state)
