-- @description pmn_Monitor: alternar Sonarworks / Sienna
-- @author Patricio Maripani Navarro
-- @version 2.1
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
--   + Pregunta el nombre del plugin si no lo encuentra
-- @about
--   Alterna entre los plugins de monitorización A y B (Sonarworks / Sienna) en la cadena
--   de monitorización del máster: activa uno y desactiva el otro.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/monitor_switch.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGINS = { "Sonarworks", "Sienna" } -- subcadenas para localizar cada plugin
local EXT_SECTION = "enemigo_monitor"
local EXT_KEY = "switch_state"

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

--------------------------------------------------------------------------------
-- Resolución de plugins: ExtState -> config -> pregunta al usuario
--------------------------------------------------------------------------------
local function resolve_plugin(i)
  local stored = reaper.GetExtState(EXT_SECTION, "plugin_" .. i)
  local name = (stored ~= "") and stored or PLUGINS[i]
  local found = find_recfx(name)
  if found then return found end

  local retval, input = reaper.GetUserInputs(
    "Monitor switch: plugin no encontrado",
    1,
    "Subcadena del nombre del plugin " .. i .. ":",
    name)
  if retval then
    input = input:gsub("^%s*(.-)%s*$", "%1")  -- recortar espacios
    if input ~= "" then
      reaper.SetExtState(EXT_SECTION, "plugin_" .. i, input, true)
      return find_recfx(input)
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Estado de toolbar: highlight del botón asignado
--------------------------------------------------------------------------------
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
local idxA = resolve_plugin(1)
local idxB = resolve_plugin(2)
if not idxA then
  reaper.ShowMessageBox(
    string.format("No se encontró el plugin \"%s\" en la cadena de monitorización.", PLUGINS[1]),
    "Monitor switch", 0)
  return
end

local aEnabled = is_enabled(idxA)
if idxB then
  set_enabled(idxA, not aEnabled)
  set_enabled(idxB, aEnabled)
else
  set_enabled(idxA, not aEnabled)
end

local state = not aEnabled
reaper.SetExtState(EXT_SECTION, EXT_KEY, state and "1" or "0", true)
set_toolbar_state(state)
