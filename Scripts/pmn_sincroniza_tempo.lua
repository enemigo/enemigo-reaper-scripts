-- @description pmn_Sincroniza tempo: calculadora de ms por división rítmica (toggle + tap tempo)
-- @author Patricio Maripani Navarro
-- @version 3.3
-- @changelog
--   + Fix: usar la API gfx global (no reaper.gfx)
--   + Prefijo pmn_ en el nombre de acción
--   + Ventana gfx nativa (sin dependencias) con toggle: disparar abre/cierra
--   + Botón TAP tempo: calcula el BPM al hacer clic (solo muestra, no modifica el proyecto)
--   + Valores redondeados a 2 decimales
--   + División 1/64 añadida
--   + Swing incluido
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tercillos, puntillos y swing) al BPM actual. Incluye un botón
--   TAP tempo que calcula el BPM al hacer clic (solo visual, no modifica el proyecto).
--   Ventana persistente: vuelve a ejecutar la acción para cerrarla.
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
  gfx.quit()
  return
end

-- Abrir
reaper.SetExtState(EXT_SECTION, EXT_KEY, "1", true)

--------------------------------------------------------------------------------
-- Ventana
--------------------------------------------------------------------------------
local LINE_H = 16
local MARGIN = 8
local BTN_H = 40
local BTN_Y_GAP = 8
local current_bpm = reaper.Master_GetTempo()
local lines = build_lines(current_bpm)

-- Alto: texto + botón TAP
local w = 260
local h = #lines * LINE_H + MARGIN * 2 + BTN_Y_GAP + BTN_H
if h < 180 then h = 180 end

gfx.init("Sincroniza tempo", w, h, 0, 100, 100)
gfx.setfont(1, "monospace", 12)

local btn_x = MARGIN
local btn_y = h - MARGIN - BTN_H
local btn_w = w - MARGIN * 2

-- Estado del tap
local last_tap = 0
local last_interval = 0
local tap_status = "TAP (clic al ritmo)"
local prev_mouse_cap = 0

local function loop()
  -- Cerrar si el usuario tocó la X o se disparó el toggle
  if not gfx.update() or reaper.GetExtState(EXT_SECTION, EXT_KEY) ~= "1" then
    reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
    gfx.quit()
    return
  end

  gfx.setfont(1, "monospace", 12)

  -- Detectar clic (flanco ascendente del botón izquierdo)
  local mc = gfx.mouse_cap or 0
  local click = (mc % 2 == 1) and (prev_mouse_cap % 2 == 0)
  prev_mouse_cap = mc

  if click then
    local mx, my = gfx.mouse_x or 0, gfx.mouse_y or 0
    if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + BTN_H then
      local now = reaper.time_precise()
      if last_tap > 0 then
        local dt = now - last_tap
        if dt > 0.25 and dt < 2.5 then
          -- promedio con el intervalo anterior para estabilizar
          local avg = dt
          if last_interval > 0 then
            avg = (dt + last_interval) / 2
          end
          current_bpm = round2(60 / avg)
          last_interval = dt
          lines = build_lines(current_bpm)
          tap_status = string.format("TAP: %.2f BPM", current_bpm)
        end
      end
      last_tap = now
    end
  end

  -- Texto de las divisiones
  gfx.setcolor(230, 230, 230, 255)
  local y = MARGIN
  for _, ln in ipairs(lines) do
    gfx.x = MARGIN
    gfx.y = y
    gfx.drawstr(ln)
    y = y + LINE_H
  end

  -- Botón TAP
  gfx.setcolor(70, 110, 170, 255)
  gfx.rect(btn_x, btn_y, btn_w, BTN_H, 1)   -- relleno
  gfx.setcolor(210, 220, 240, 255)
  gfx.rect(btn_x, btn_y, btn_w, BTN_H, 0)   -- borde
  gfx.x = btn_x + MARGIN
  gfx.y = btn_y + 12
  gfx.drawstr(tap_status)

  gfx.defer(loop)
end

gfx.defer(loop)
