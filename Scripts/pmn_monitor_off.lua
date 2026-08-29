-- @description pmn_Monitor: bypass SoundID y Sienna
-- @author Patricio Maripani Navarro
-- @version 2.3
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Fallback por posición si no encuentra por nombre (fix: se activaba antes)
--   + Nombres por defecto: SoundID / Sienna
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
--   + Pregunta el nombre del plugin si no lo encuentra
-- @about
--   Alterna el bypass de los plugins SoundID y Sienna de la cadena de monitorización
--   del máster: si alguno está activo, los apaga todos; si están apagados, los enciende.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_monitor_off.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGINS = { "SoundID", "Sienna" } -- subcadenas para localizar cada plugin
local POSITIONS = { 4, 5 }          -- fallback: posiciones 1-based de cada plugin
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

-- Fallback por posición 1-based (si el plugin no aparece por nombre)
local function recfx_by_pos(pos)
  local cnt = reaper.TrackFX_GetRecCount(track)
  if pos and pos >= 1 and pos <= cnt then
    return pos - 1
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
-- Resolución de plugins: ExtState -> config (nombre) -> posición -> pregunta
--------------------------------------------------------------------------------
local function resolve_plugin(i)
  local stored = reaper.GetExtState(EXT_SECTION, "plugin_" .. i)
  local name = (stored ~= "") and stored or PLUGINS[i]
  local found = find_recfx(name)
  if found then return found end

  if stored == "" then
    local bypos = recfx_by_pos(POSITIONS[i])
    if bypos then return bypos end
  end

  local retval, input = reaper.GetUserInputs(
    "Monitor off: plugin no encontrado",
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
local anyEnabled = false
local found = 0
for i = 1, #PLUGINS do
  idx[i] = resolve_plugin(i)
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
