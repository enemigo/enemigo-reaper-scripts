-- @description pmn_Sincroniza tempo: calculadora de ms por división rítmica
-- @author Patricio Maripani Navarro
-- @version 2.2
-- @changelog
--   + Prefijo pmn_ en el nombre de acción
--   + Ventana interactiva (ReaImGui) si está instalada
--   + Interfaz clásica (ShowMessageBox) como fallback si no hay ReaImGui
--   + BPM editable en vivo, valores redondeados a 2 decimales
--   + División 1/64 añadida
--   + Soporte de tempo maps (varios BPM por sección)
--   + Copiar valor al portapapeles con un clic
--   + Swing ajustable (%)
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tercillos, puntillos y swing) al BPM actual (o por sección si el
--   proyecto tiene tempo map). Usa ReaImGui si está instalado; si no, muestra
--   una caja de texto clásica.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_sincroniza_tempo.lua

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function round2(n)
  return math.floor(n * 100 + 0.5) / 100
end

local NOTE_DIVISIONS = { "1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64" }
local KIND_LABELS = { straight = "Directo", triplet = "Tercillo", dotted = "Puntillo", swing = "Swing" }

-- ms por división: whole = 60000/bpm; factor directo / tercillo / puntillo
local function ms_for(bpm, div, kind)
  local base = 60000 / bpm / div
  if kind == "straight" then return base end
  if kind == "triplet" then return base * (2 / 3) end
  if kind == "dotted" then return base * (3 / 2) end
  return base -- swing (se calcula abajo)
end

-- Obtener lista de {bpm, ts} del tempo map; si no hay markers, uno con el BPM actual
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

-- Formatea la fila de una división, con swing si aplica
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

--------------------------------------------------------------------------------
-- INTERFAZ CLÁSICA (fallback sin ReaImGui)
--------------------------------------------------------------------------------
local function build_classic_text(bpm, swing_pct)
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

local function run_classic()
  local tempos = get_tempos()
  if #tempos == 1 then
    reaper.ShowMessageBox(build_classic_text(tempos[1].bpm, 50), "Sincroniza tempo", 0)
  else
    -- con tempo map, listar por sección (texto plano)
    local parts = {}
    for i, t in ipairs(tempos) do
      parts[#parts + 1] = string.format(
        "== Sección %d  (BPM %.2f%s) ==\n%s",
        i, t.bpm, t.ts and "  " .. t.ts or "", build_classic_text(t.bpm, 50))
    end
    reaper.ShowMessageBox(table.concat(parts, "\n\n"), "Sincroniza tempo", 0)
  end
end

--------------------------------------------------------------------------------
-- INTERFAZ ReaImGui (si está disponible)
--------------------------------------------------------------------------------
local imgui = nil
if reaper.ImGui_GetBuiltinPath then
  local ok, loaded = pcall(dofile, reaper.ImGui_GetBuiltinPath() .. "/imgui.lua")
  if ok and loaded then imgui = loaded end
end

local function run_imgui()
  local bpm_state = { value = reaper.Master_GetTempo() }
  local swing_state = { value = 50 }
  local clipboard_result = { text = "" }
  local clipboard_timer = 0

  local function copy_to_clipboard(text)
    reaper.CF_SetClipboard(text)
    clipboard_result.text = "Copiado: " .. text
    clipboard_timer = os.clock()
  end

  local function draw_division_table(ctx, bpm, kind)
    if not imgui.BeginTable(ctx, "tabla_" .. kind, 3) then return end
    imgui.TableSetupColumn(ctx, "División")
    imgui.TableSetupColumn(ctx, "ms")
    imgui.TableSetupColumn(ctx, "")
    imgui.TableHeadersRow(ctx)

    for _, div in ipairs(NOTE_DIVISIONS) do
      local ms = compute_ms(bpm, div, kind, swing_state.value)
      imgui.TableNextRow(ctx)
      imgui.TableNextColumn(ctx)
      imgui.Text(ctx, div)
      imgui.TableNextColumn(ctx)
      imgui.Text(ctx, string.format("%.2f", ms))
      imgui.TableNextColumn(ctx)
      if imgui.Button(ctx, "Copia##" .. kind .. div) then
        copy_to_clipboard(string.format("%.2f", ms))
      end
    end
    imgui.EndTable(ctx)
  end

  local ctx = imgui.CreateContext("Sincroniza tempo")

  local function loop()
    local visible, open = imgui.Begin(ctx, "Sincroniza tempo", true)
    if visible then
      local tempos = get_tempos()

      if #tempos > 0 then
        imgui.SetNextItemWidth(ctx, 120)
        local changed = imgui.InputDouble(ctx, "BPM", bpm_state.value, 0.5)
        if changed then
          bpm_state.value = math.max(1, bpm_state.value)
        end
      end

      imgui.SetNextItemWidth(ctx, 120)
      imgui.SliderInt(ctx, "Swing %", swing_state.value, 0, 100)

      if #tempos > 1 then
        imgui.Text(ctx, "Tempo map detectado: " .. #tempos .. " sección(es)")
      end

      imgui.Separator(ctx)

      for ti, t in ipairs(tempos) do
        local label = string.format("BPM %.2f%s", t.bpm, t.ts and ("  (" .. t.ts .. ")") or "")
        local label2 = (#tempos > 1) and (label .. "  [sección " .. ti .. "]") or label
        imgui.Text(ctx, label2)
        for _, kind in ipairs({ "straight", "triplet", "dotted", "swing" }) do
          if imgui.CollapsingHeader(ctx, KIND_LABELS[kind] .. "##" .. ti .. kind) then
            draw_division_table(ctx, t.bpm, kind)
          end
        end
        imgui.Separator(ctx)
      end

      if clipboard_result.text ~= "" then
        imgui.TextColored(ctx, 0.3, 0.8, 0.3, 1.0, clipboard_result.text)
        if os.clock() - clipboard_timer > 2 then
          clipboard_result.text = ""
        end
      end
    end

    if open then
      imgui.End(ctx)
      reaper.defer(loop)
    end
  end

  reaper.defer(loop)
end

--------------------------------------------------------------------------------
-- MAIN: elegir interfaz
--------------------------------------------------------------------------------
if imgui then
  run_imgui()
else
  run_classic()
end
