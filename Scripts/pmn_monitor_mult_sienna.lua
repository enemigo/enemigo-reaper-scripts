-- @description pmn_Monitor: alternar Sonarworks / Sienna / Extra (Sienna offline en Extra)
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
--   + Pregunta el nombre del plugin si no lo encuentra
-- @about
--   Cicla entre tres plugins de monitorización del máster (Sonarworks, Sienna y Extra). Al
--   pasar a "Extra" deja Sienna offline; al volver a Sonarworks la reactiva.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_monitor_mult_sienna.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGINS = { "Sonarworks", "Sienna", "Extra" } -- subcadenas para localizar cada plugin
local EXT_SECTION = "enemigo_monitor"
local EXT_KEY = "mult_sienna_state"

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

local function set_offline(idx, offline)
  if idx then reaper.TrackFX_SetOffline(track, RECFX + idx, offline) end
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
-- Resolución de plugins: ExtState -> config -> pregunta al usuario
--------------------------------------------------------------------------------
local function resolve_plugin(i)
  local stored = reaper.GetExtState(EXT_SECTION, "plugin_" .. i)
  local name = (stored ~= "") and stored or PLUGINS[i]
  local found = find_recfx(name)
  if found then return found end

  local retval, input = reaper.GetUserInputs(
    "Monitor mult sienna: plugin no encontrado",
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
-- MAIN
--------------------------------------------------------------------------------
local idx = {}
for i = 1, #PLUGINS do
  idx[i] = resolve_plugin(i)
end

if not idx[1] then
  reaper.ShowMessageBox(
    string.format("No se encontró el plugin \"%s\" en la cadena de monitorización.", PLUGINS[1]),
    "Monitor mult sienna", 0)
  return
end

local current = 1
for i = 1, #idx do
  if idx[i] and is_enabled(idx[i]) then
    current = i
    break
  end
end

local next = current % #PLUGINS + 1
for i = 1, #idx do
  if idx[i] then set_enabled(idx[i], i == next) end
end

-- Comportamiento extra: al pasar a "Extra" (índice 3), Sienna queda offline
if next == #PLUGINS then
  set_offline(idx[3], true)
else
  set_offline(idx[3], false)
end

local state = idx[next] and is_enabled(idx[next]) or false
reaper.SetExtState(EXT_SECTION, EXT_KEY, state and "1" or "0", true)
set_toolbar_state(state)
