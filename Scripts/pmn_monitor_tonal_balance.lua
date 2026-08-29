-- @description pmn_Monitor: mostrar/ocultar Tonal Balance Control
-- @author Patricio Maripani Navarro
-- @version 2.2
-- @changelog
--   + Detección de plugins por nombre (ya no depende de posición fija)
--   + Fallback por posición si no encuentra por nombre
--   + Mensaje de error si no se encuentra el plugin
--   + Pregunta el nombre del plugin si no lo encuentra
-- @about
--   Muestra u oculta la ventana del plugin Tonal Balance Control en la cadena
--   de monitorización del máster.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_monitor_tonal_balance.lua

--------------------------------------------------------------------------------
-- CONFIG (personalizá libremente)
--------------------------------------------------------------------------------
local PLUGIN = "Tonal Balance"     -- subcadena para localizar el plugin
local POS_TONAL = 2                 -- fallback: posición 1-based en la cadena de monitorización
local EXT_SECTION = "enemigo_monitor"

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

--------------------------------------------------------------------------------
-- Resolución de plugins: ExtState -> config (nombre) -> posición -> pregunta
--------------------------------------------------------------------------------
local function resolve_plugin()
  local stored = reaper.GetExtState(EXT_SECTION, "plugin_tonal")
  local name = (stored ~= "") and stored or PLUGIN
  local found = find_recfx(name)
  if found then return found end

  if stored == "" then
    local bypos = recfx_by_pos(POS_TONAL)
    if bypos then return bypos end
  end

  local retval, input = reaper.GetUserInputs(
    "Monitor Tonal Balance: plugin no encontrado",
    1,
    "Subcadena del nombre del plugin:",
    name)
  if retval then
    input = input:gsub("^%s*(.-)%s*$", "%1")  -- recortar espacios
    if input ~= "" then
      reaper.SetExtState(EXT_SECTION, "plugin_tonal", input, true)
      return find_recfx(input)
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
local idx = resolve_plugin()
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
