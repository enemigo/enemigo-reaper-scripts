-- @description pmn_Monitor: alternar SoundID / Sienna
-- @author Patricio Maripani Navarro
-- @version 2.7
-- @changelog
--   + Fix: TrackFX_GetEnabled puede devolver booleano (is_enabled y log)
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Fallback por posición si no encuentra por nombre (fix: se activaba antes)
--   + Toggle robusto: si falta un plugin, alterna el que existe; error si faltan ambos
--   + Log de debug (lista cadena y muestra cómo resuelve cada plugin)
--   + Nombres por defecto: SoundID / Sienna
--   + Estado persistido en ExtState y refresh de toolbar
--   + Eliminado reaper.defer() innecesario
--   + Pregunta el nombre del plugin si no lo encuentra
-- @about
--   Alterna entre los plugins de monitorización A y B (SoundID / Sienna) en la cadena
--   de monitorización del máster: activa uno y desactiva el otro.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_monitor_switch.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGINS = { "SoundID", "Sienna" } -- subcadenas para localizar cada plugin
local POSITIONS = { 4, 5 }          -- fallback: posiciones 1-based de cada plugin
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
  if not idx then return false end
  local v = reaper.TrackFX_GetEnabled(track, RECFX + idx)
  return (v == 1) or (v == true)
end

--------------------------------------------------------------------------------
-- LOG (debug)
--------------------------------------------------------------------------------
local DEBUG = true

local function log(msg)
  if DEBUG then
    reaper.ShowConsoleMsg("[monitor_switch] " .. msg .. "\n")
  end
end

local function log_rec_chain()
  local cnt = reaper.TrackFX_GetRecCount(track)
  log("Cadena de monitorización (" .. cnt .. " plugins):")
  for i = 0, cnt - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, RECFX + i, "")
    local en = reaper.TrackFX_GetEnabled(track, RECFX + i)
    log(string.format("  [%d] (0-based %d) %s  enabled=%s", i + 1, i, ok and name or "?", tostring(en)))
  end
end

--------------------------------------------------------------------------------
-- Resolución de plugins: ExtState -> config (nombre) -> posición -> pregunta
--------------------------------------------------------------------------------
local function resolve_plugin(i)
  local stored = reaper.GetExtState(EXT_SECTION, "plugin_" .. i)
  local name = (stored ~= "") and stored or PLUGINS[i]
  local found = find_recfx(name)
  if found then
    log(string.format("Plugin %d: encontrado por NOMBRE \"%s\" -> index %d", i, name, found))
    return found
  end
  log(string.format("Plugin %d: NO encontrado por nombre \"%s\"", i, name))

  if stored == "" then
    local bypos = recfx_by_pos(POSITIONS[i])
    if bypos then
      log(string.format("Plugin %d: fallback por POSICIÓN %d -> index %d", i, POSITIONS[i], bypos))
      return bypos
    end
    log(string.format("Plugin %d: posición %d fuera de rango", i, POSITIONS[i]))
  else
    log(string.format("Plugin %d: tiene nombre guardado en ExtState (%s), no uso posición", i, stored))
  end

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
log_rec_chain()
local idxA = resolve_plugin(1)
local idxB = resolve_plugin(2)

if not idxA and not idxB then
  reaper.ShowMessageBox(
    string.format("No se encontró ninguno de los plugins (%s) en la cadena de monitorización.",
      table.concat(PLUGINS, ", ")),
    "Monitor switch", 0)
  return
end

local state
if idxA and idxB then
  -- Toggle limpio entre ambos: activa A si estaba apagado (o viceversa),
  -- dejando siempre exactamente uno activo.
  local aEnabled = is_enabled(idxA)
  log(string.format("Toggle: A enabled=%s -> enciendo A=%s, B=%s", tostring(aEnabled), tostring(not aEnabled), tostring(aEnabled)))
  set_enabled(idxA, not aEnabled)
  set_enabled(idxB, aEnabled)
  state = not aEnabled
else
  -- Solo uno disponible: toggle on/off del que existe
  local only = idxA or idxB
  local on = is_enabled(only)
  log(string.format("Un solo plugin (index %d): enabled=%s -> new=%s", only, tostring(on), tostring(not on)))
  set_enabled(only, not on)
  state = not on
end

reaper.SetExtState(EXT_SECTION, EXT_KEY, state and "1" or "0", true)
set_toolbar_state(state)
