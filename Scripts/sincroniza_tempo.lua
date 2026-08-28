-- @description Sincroniza tempo: calculadora de ms por división rítmica (ReaImGui)
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Ventana interactiva (ReaImGui) en lugar de ShowMessageBox
--   + BPM editable en vivo, valores redondeados a 2 decimales
--   + División 1/64 añadida
--   + Soporte de tempo maps (varios BPM por sección)
--   + Copiar valor al portapapeles con un clic
--   + Swing ajustable (%)
-- @about
--   Calculadora de duraciones en milisegundos para las divisiones rítmicas
--   (directas, tercillos, puntillos y swing) al BPM actual (o por sección si el
--   proyecto tiene tempo map). Permite copiar cada valor al portapapeles.
-- @requires ReaImGui
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/sincroniza_tempo.lua

--------------------------------------------------------------------------------
-- Cargar ReaImGui
--------------------------------------------------------------------------------
if not reaper.ImGui_GetBuiltinPath then
  reaper.ShowMessageBox("ReaImGui no está instalado.\nInstálalo desde ReaPack (ReaTeam Extensions).", "Sincroniza tempo", 0)
  return
end

local imgui = dofile(reaper.ImGui_GetBuiltinPath() .. "/imgui.lua")
if not imgui then
  reaper.ShowMessageBox("No se pudo cargar ReaImGui.", "Sincroniza tempo", 0)
  return
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function round2(n)
  return math.floor(n * 100 + 0.5) / 100
end

local NOTE_DIVISIONS = { "1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64" }

-- ms por división: whole = 60000/bpm; factor directo / tercillo / puntillo
local function ms_for(bpm, div, kind)
  local base = 60000 / bpm / div
  if kind == "straight" then return base end
  if kind == "triplet" then return base * (2 / 3) end
  if kind == "dotted" then return base * (3 / 2) end
  return base -- swing (se calcula abajo)
end

-- Obtener lista de {bpm, measure_den} del tempo map; si no hay markers, uno con el BPM actual
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

--------------------------------------------------------------------------------
-- Estado de la ventana
--------------------------------------------------------------------------------
local bpm_state = { value = reaper.Master_GetTempo() }
local swing_state = { value = 50 } -- %
local clipboard_result = { text = "" }
local clipboard_timer = 0

local function copy_to_clipboard(text)
  reaper.CF_SetClipboard(text)
  clipboard_result.text = "Copiado: " .. text
  clipboard_timer = os.clock()
end

--------------------------------------------------------------------------------
-- Dibujar una tabla de divisiones
--------------------------------------------------------------------------------
local KIND_LABELS = { straight = "Directo", triplet = "Tercillo", dotted = "Puntillo", swing = "Swing" }

local function draw_division_table(ctx, bpm, kind)
  if not imgui.BeginTable(ctx, "tabla_" .. kind, 3) then return end
  imgui.TableSetupColumn(ctx, "División")
  imgui.TableSetupColumn(ctx, "ms")
  imgui.TableSetupColumn(ctx, "")
  imgui.TableHeadersRow(ctx)

  for _, div in ipairs(NOTE_DIVISIONS) do
    local divisor = tonumber(div:match("/(%d+)"))
    local ms = ms_for(bpm, divisor, kind)

    -- Swing: tercillo con acento 2:1 (swing %)
    if kind == "swing" then
      local trip = ms_for(bpm, divisor, "triplet")
      local pct = swing_state.value / 100
      local long = trip * (pct * 2)
      local short = trip * ((1 - pct) * 2)
      ms = round2(long + short)
    end

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

--------------------------------------------------------------------------------
-- Loop principal
--------------------------------------------------------------------------------
local ctx = imgui.CreateContext("Sincroniza tempo")

local function loop()
  local visible, open = imgui.Begin(ctx, "Sincroniza tempo", true)
  if visible then
    local tempos = get_tempos()

    -- BPM editable (aplica al primer tempo)
    if #tempos > 0 then
      imgui.SetNextItemWidth(ctx, 120)
      local changed = imgui.InputDouble(ctx, "BPM", bpm_state.value, 0.5)
      if changed then
        bpm_state.value = math.max(1, bpm_state.value)
      end
    end

    imgui.SetNextItemWidth(ctx, 120)
    imgui.SliderInt(ctx, "Swing %", swing_state.value, 0, 100)

    local use_bpm = bpm_state.value
    if #tempos > 1 then
      imgui.Text(ctx, "Tempo map detectado: " .. #tempos .. " sección(es)")
    end

    imgui.Separator(ctx)

    -- Una tabla por grupo (o por sección si hay tempo map)
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

    if #tempos <= 1 then
      -- Con un solo tempo, usar el BPM editable en vivo
      for _, kind in ipairs({ "straight", "triplet", "dotted", "swing" }) do
        if imgui.CollapsingHeader(ctx, KIND_LABELS[kind] .. "##" .. kind) then
          draw_division_table(ctx, use_bpm, kind)
        end
      end
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
