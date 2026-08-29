-- @description pmn_Sincroniza tempo: calculadora de ms por división rítmica (toggle + tap tempo)
-- @author Patricio Maripani Navarro
-- @version 3.6
-- @changelog
--   + Fix: usar gfx.set (valores 0-1) en vez de gfx.setcolor
--   + Fallback con pcall: si la ventana gfx falla, muestra la tabla clásica (ShowMessageBox)
--   + Corregido "Tercillo" -> "Tresillo"
--   + Fix: usar reaper.defer (no gfx.defer) para el loop
--   + Fix: usar la API gfx global (no reaper.gfx)
--   + Ventana gfx nativa con toggle y botón TAP tempo (solo muestra BPM)
--   + Valores redondeados a 2 decimales, división 1/64, swing
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tresillos, puntillos y swing) al BPM actual. Incluye un botón
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
local KIND_LABELS = { straight = "Directo", triplet = "Tresillo", dotted = "Puntillo", swing = "Swing" }

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
-- Modo clásico (fallback): tabla en ShowMessageBox
--------------------------------------------------------------------------------
local function run_classic()
  local bpm = reaper.Master_GetTempo()
  local lines = build_lines(bpm)
  reaper.ShowMessageBox(table.concat(lines, "\n"), "Sincroniza tempo", 0)
end

--------------------------------------------------------------------------------
-- Modo gfx: ventana persistente con toggle y TAP
--------------------------------------------------------------------------------
local function run_gfx()
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

  local LINE_H = 16
  local MARGIN = 8
  local BTN_H = 40
  local BTN_Y_GAP = 8
  local current_bpm = reaper.Master_GetTempo()
  local lines = build_lines(current_bpm)

  local w = 260
  local h = #lines * LINE_H + MARGIN * 2 + BTN_Y_GAP + BTN_H
  if h < 180 then h = 180 end

  gfx.init("Sincroniza tempo", w, h, 0, 100, 100)
  gfx.setfont(1, "monospace", 12)

  local btn_x = MARGIN
  local btn_y = h - MARGIN - BTN_H
  local btn_w = w - MARGIN * 2

  local last_tap = 0
  local last_interval = 0
  local tap_status = "TAP (clic al ritmo)"
  local prev_mouse_cap = 0

  local function loop()
    if not gfx.update() or reaper.GetExtState(EXT_SECTION, EXT_KEY) ~= "1" then
      reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
      gfx.quit()
      return
    end

    gfx.setfont(1, "monospace", 12)

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

    gfx.set(0.9, 0.9, 0.9, 1)
    local y = MARGIN
    for _, ln in ipairs(lines) do
      gfx.x = MARGIN
      gfx.y = y
      gfx.drawstr(ln)
      y = y + LINE_H
    end

    gfx.set(0.27, 0.43, 0.67, 1)
    gfx.rect(btn_x, btn_y, btn_w, BTN_H, 1)
    gfx.set(0.82, 0.86, 0.94, 1)
    gfx.rect(btn_x, btn_y, btn_w, BTN_H, 0)
    gfx.x = btn_x + MARGIN
    gfx.y = btn_y + 12
    gfx.drawstr(tap_status)

    reaper.defer(loop)
  end

  reaper.defer(loop)
end

--------------------------------------------------------------------------------
-- MAIN: intentar gfx, si falla usar clásico
--------------------------------------------------------------------------------
local ok, err = pcall(run_gfx)
if not ok then
  reaper.SetExtState("enemigo_tempo", "open", "0", true)
  run_classic()
end
