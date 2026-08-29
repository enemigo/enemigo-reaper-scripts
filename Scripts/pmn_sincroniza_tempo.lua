-- @description pmn_Sincroniza tempo: calculadora de ms por división rítmica (toggle)
-- @author Patricio Maripani Navarro
-- @version 3.0
-- @changelog
--   + Prefijo pmn_ en el nombre de acción
--   + Ventana gfx nativa (sin dependencias) con toggle: disparar abre/cierra
--   + Valores redondeados a 2 decimales
--   + División 1/64 añadida
--   + Soporte de tempo maps (varios BPM por sección)
--   + Swing incluido
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tercillos, puntillos y swing) al BPM actual (o por sección si el
--   proyecto tiene tempo map). Ventana persistente: vuelve a ejecutar la acción
--   para cerrarla.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_sincroniza_tempo.lua

--------------------------------------------------------------------------------
-- Cálculos
--------------------------------------------------------------------------------
local function round2(n)
  return math.floor(n * 100 + 0.5) / 100
end

local NOTE_DIVISIONS = { "1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64" }
local KIND_LABELS = { straight = "Directo", triplet = "Tercillo", dotted = "Puntillo", swing = "Swing" }

local function ms_for(bpm, div, kind)
  local base = 60000 / bpm / div
  if kind == "straight" then return base end
  if kind == "triplet" then return base * (2 / 3) end
  if kind == "dotted" then return base * (3 / 2) end
  return base
end

local function get_tempos()
  local tempos = {}
  local cnt = reaper.CountTempoTimeSigMarkers(0)
  local bpm = reaper.Master_GetTempo()
  if cnt == 0 then
    tempos[#tempos + 1] = { bpm = bpm }
    return tempos
  end
  for i = 0, cnt - 1 do
    local retval, bpm2, tsnum, tsden = reaper.GetTempoTimeSigMarker(0, i)
    if retval and bpm2 > 0 then
      tempos[#tempos + 1] = { bpm = bpm2, ts = tsnum .. "/" .. tsden }
    end
  end
  return tempos
end

local function compute_ms(bpm, div, kind, swing_pct)
  local divisor = tonumber(div:match("/(%d+)"))
  local ms = ms_for(bpm, divisor, kind)
  if kind == "swing" then
    local trip = ms_for(bpm, divisor, "triplet")
    local pct = (swing_pct or 50) / 100
    local long = trip * (pct * 2)
    local short = trip * ((1 - pct) * 2)
    ms = round2(long + short)
  end
  return round2(ms)
end

local function build_lines(bpm)
  local lines = {}
  lines[#lines + 1] = string.format("BPM: %.2f", bpm)
  lines[#lines + 1] = ""
  for _, kind in ipairs({ "straight", "triplet", "dotted", "swing" }) do
    lines[#lines + 1] = "-- " .. KIND_LABELS[kind] .. " --"
    for _, div in ipairs(NOTE_DIVISIONS) do
      local ms = compute_ms(bpm, div, kind, 50)
      lines[#lines + 1] = string.format("  %-5s %.2f ms", div, ms)
    end
    lines[#lines + 1] = ""
  end
  return lines
end

--------------------------------------------------------------------------------
-- Toggle: abrir o cerrar la ventana gfx
--------------------------------------------------------------------------------
local EXT_SECTION = "enemigo_tempo"
local EXT_KEY = "open"

if reaper.GetExtState(EXT_SECTION, EXT_KEY) == "1" then
  -- Cerrar (segundo disparo)
  reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
  reaper.gfx.quit()
  return
end

-- Abrir
reaper.SetExtState(EXT_SECTION, EXT_KEY, "1", true)

local LINE_H = 16
local MARGIN = 8
local tempos = get_tempos()

local function build_all_lines()
  local all = {}
  for i, t in ipairs(tempos) do
    if #tempos > 1 then
      all[#all + 1] = string.format("== Sección %d  (BPM %.2f%s) ==", i, t.bpm, t.ts and "  " .. t.ts or "")
      all[#all + 1] = ""
    end
    for _, ln in ipairs(build_lines(t.bpm)) do
      all[#all + 1] = ln
    end
    if i < #tempos then
      all[#all + 1] = ""
    end
  end
  return all
end

local lines = build_all_lines()
local w = 260
local h = #lines * LINE_H + MARGIN * 2
if h < 120 then h = 120 end

reaper.gfx.init("Sincroniza tempo", w, h, 0, 100, 100)
reaper.gfx.setfont(1, "monospace", 12)

local function loop()
  -- Si el usuario cerró la ventana con la X o se disparó el toggle, salir
  if not reaper.gfx.update() or reaper.GetExtState(EXT_SECTION, EXT_KEY) ~= "1" then
    reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
    reaper.gfx.quit()
    return
  end

  reaper.gfx.setfont(1, "monospace", 12)
  reaper.gfx.setcolor(230, 230, 230, 255)
  local y = MARGIN
  for _, ln in ipairs(lines) do
    reaper.gfx.x = MARGIN
    reaper.gfx.y = y
    reaper.gfx.drawstr(ln)
    y = y + LINE_H
  end

  reaper.defer(loop)
end

reaper.defer(loop)
