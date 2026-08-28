-- @description Monitor: bypass Sonarworks y Sienna
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
-- @about
--   Alterna el bypass de los plugins Sonarworks y Sienna de la cadena de monitorización
--   del máster: si alguno está activo, los apaga todos; si están apagados, los enciende.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/monitor_off.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGINS = { "Sonarworks", "Sienna" } -- subcadenas para localizar cada plugin
local EXT_SECTION = "enemigo_monitor"
local EXT_KEY = "off_state"

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

local function set_enabled(idx, enabled)
  if idx then reaper.TrackFX_SetEnabled(track, RECFX + idx, enabled) end
end

local function is_enabled(idx)
  return idx and (reaper.TrackFX_GetEnabled(track, RECFX + idx) == 1) or false
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
local idx = {}
local anyEnabled = false
local found = 0
for i = 1, #PLUGINS do
  idx[i] = find_recfx(PLUGINS[i])
  if idx[i] then
    found = found + 1
    if is_enabled(idx[i]) then anyEnabled = true end
  end
end

if found == 0 then
  reaper.ShowMessageBox(
    string.format("No se encontró ninguno de los plugins (%s) en la cadena de monitorización.", table.concat(PLUGINS, ", ")),
    "Monitor off", 0)
  return
end

local state = not anyEnabled
for i = 1, #idx do
  set_enabled(idx[i], state)
end

reaper.SetExtState(EXT_SECTION, EXT_KEY, state and "1" or "0", true)
set_toolbar_state(state)
