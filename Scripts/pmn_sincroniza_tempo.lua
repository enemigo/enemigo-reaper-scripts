-- @description pmn_Sincroniza tempo: calculadora de ms por división rítmica
-- @author Patricio Maripani Navarro
-- @version 2.3
-- @changelog
--   + Prefijo pmn_ en el nombre de acción
--   + Se quita la dependencia de ReaImGui (interfaz clásica)
--   + Valores redondeados a 2 decimales
--   + División 1/64 añadida
--   + Soporte de tempo maps (varios BPM por sección)
--   + Swing ajustable (%)
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tercillos, puntillos y swing) al BPM actual (o por sección si el
--   proyecto tiene tempo map).
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_sincroniza_tempo.lua

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

local function build_text(bpm, swing_pct)
  local lines = {}
  lines[#lines + 1] = string.format("BPM: %.2f\n", bpm)
  for _, kind in ipairs({ "straight", "triplet", "dotted", "swing" }) do
    lines[#lines + 1] = "---- " .. KIND_LABELS[kind] .. " ----"
    for _, div in ipairs(NOTE_DIVISIONS) do
      local ms = compute_ms(bpm, div, kind, swing_pct)
      lines[#lines + 1] = string.format("%-5s %.2f ms", div, ms)
    end
    lines[#lines + 1] = ""
  end
  return table.concat(lines, "\n")
end

local function main()
  local tempos = get_tempos()
  if #tempos == 1 then
    reaper.ShowMessageBox(build_text(tempos[1].bpm, 50), "Sincroniza tempo", 0)
  else
    local parts = {}
    for i, t in ipairs(tempos) do
      parts[#parts + 1] = string.format(
        "== Sección %d  (BPM %.2f%s) ==\n%s",
        i, t.bpm, t.ts and "  " .. t.ts or "", build_text(t.bpm, 50))
    end
    reaper.ShowMessageBox(table.concat(parts, "\n\n"), "Sincroniza tempo", 0)
  end
end

main()
