-- @description pmn_AUTO FREEZE ReaInsert (copy routing, color, MASTER SEND state, smart mono/stereo, go to 0 and RECORD)
-- @author Patricio Maripani Navarro
-- @version 2.1
-- @changelog
--   + Prefijo pmn_ en el nombre de acción
--   + Vacía la cadena FX de la pista FREEZE al crearla
--   + Maneja el estado de transporte (guarda play/record y lo retoma)
--   + Verifica tras la grabación que las takes no estén vacías
-- @about
--   Crea pistas FREEZE bajo las que tienen un ReaInsert activo, copiando color, canales,
--   estado de master send y sends. Decide mono/estéreo de forma inteligente y graba desde el inicio.
-- @requires SWS Extension
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_freeze_reainsert.lua

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local VERIFY_RECORDING = true       -- tras grabar, comprobar takes vacías y avisar
local STOP_AFTER_ITEM = true        -- detener la grabación tras el primer ítem grabado (print punch)

--------------------------------------------------------------------------------
-- Detect active ReaInsert
--------------------------------------------------------------------------------
local function has_active_reainsert(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = 0, fx_count - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and name and name:match("ReaInsert") then
      if reaper.TrackFX_GetEnabled(track, fx) then
        return true
      end
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Smart mono / stereo decision
--------------------------------------------------------------------------------
local function should_print_mono(track)
  local nchan = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
  if nchan and nchan <= 1 then return true end

  local width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
  if width and math.abs(width) < 1e-9 then return true end

  local item_count = reaper.CountTrackMediaItems(track)
  if item_count == 0 then return false end

  local saw_mono_audio = false

  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local take = reaper.GetActiveTake(item)
    if take then
      if reaper.TakeIsMIDI(take) then return false end
      local src = reaper.GetMediaItemTake_Source(take)
      if src then
        local ch = reaper.GetMediaSourceNumChannels(src)
        if ch and ch >= 2 then return false end
        if ch == 1 then saw_mono_audio = true end
      end
    end
  end

  return saw_mono_audio
end

--------------------------------------------------------------------------------
-- Copy send parameters correctly
--------------------------------------------------------------------------------
local function copy_send_params(src_tr, src_idx, dst_tr, dst_idx)
  local keys = {
    "D_VOL", "D_PAN", "D_PANLAW",
    "B_MUTE", "B_PHASE",
    "I_SENDMODE", "I_SRCCHAN",
    "I_DSTCHAN", "I_MIDIFLAGS"
  }
  for _, k in ipairs(keys) do
    local v = reaper.GetTrackSendInfo_Value(src_tr, 0, src_idx, k)
    reaper.SetTrackSendInfo_Value(dst_tr, 0, dst_idx, k, v)
  end
end

--------------------------------------------------------------------------------
-- Copy all sends FROM original TO freeze
--------------------------------------------------------------------------------
local function preserve_sends(from_track, to_track)
  local send_count = reaper.GetTrackNumSends(from_track, 0)
  for i = 0, send_count - 1 do
    local dest = reaper.BR_GetMediaTrackSendInfo_Track(from_track, 0, i, 1)
    if dest then
      local new_send = reaper.CreateTrackSend(to_track, dest)
      copy_send_params(from_track, i, to_track, new_send)
    end
  end
end

--------------------------------------------------------------------------------
-- Clear ALL FX from a track (the FREEZE track must be dry)
--------------------------------------------------------------------------------
local function clear_fx_chain(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = fx_count - 1, 0, -1 do
    reaper.TrackFX_Delete(track, fx)
  end
end

--------------------------------------------------------------------------------
-- Freeze one track
--------------------------------------------------------------------------------
local function freeze_track(track, idx)
  local color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
  local nchan = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")

  -- CAPTURAR ESTADO REAL DEL MASTER SEND
  local master_send = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")
  master_send = (master_send and master_send > 0.5) and 1 or 0

  -- Insert FREEZE just below
  reaper.InsertTrackAtIndex(idx + 1, true)
  local freeze = reaper.GetTrack(0, idx + 1)

  -- Name
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  reaper.GetSetMediaTrackInfo_String(freeze, "P_NAME", "FREEZE – " .. (name or ""), true)

  -- Copy basic properties
  reaper.SetMediaTrackInfo_Value(freeze, "I_CUSTOMCOLOR", color)
  reaper.SetMediaTrackInfo_Value(freeze, "I_NCHAN", nchan)

  -- Copy sends
  preserve_sends(track, freeze)

  -- Create print send original -> freeze
  reaper.CreateTrackSend(track, freeze)

  -- Arm + monitor
  reaper.SetMediaTrackInfo_Value(freeze, "I_RECARM", 1)
  reaper.SetMediaTrackInfo_Value(freeze, "I_MONITOR", 1)

  -- Mono / stereo record mode
  local mono = should_print_mono(track)
  reaper.SetMediaTrackInfo_Value(freeze, "I_RECMODE", mono and 5 or 1)

  -- FORZAR MASTER SEND AL FINAL
  reaper.SetMediaTrackInfo_Value(freeze, "B_MAINSEND", master_send)

  -- La pista FREEZE se graba seca: sin FX
  clear_fx_chain(freeze)

  return freeze
end

--------------------------------------------------------------------------------
-- Record state helpers
--------------------------------------------------------------------------------
local saved_edit_pos = nil
local was_playing = false

local function save_transport_state()
  saved_edit_pos = reaper.GetCursorPositionEx(0)
  local bits = reaper.GetPlayStateEx(0)
  was_playing = math.floor(bits % 2) == 1  -- bit 0: playing
end

-- Restaurar posición y estado de transporte tras grabar
local function restore_transport_state()
  if saved_edit_pos then
    reaper.SetEditCurPos(saved_edit_pos, true, false)
  end
  if was_playing then
    reaper.Main_OnCommand(1007, 0)  -- Transport: Play
  end
end

--------------------------------------------------------------------------------
-- Verificación de grabación (takes vacías)
--------------------------------------------------------------------------------
local function item_has_audio(item)
  local take = reaper.GetActiveTake(item)
  if not take then return false end
  if reaper.TakeIsMIDI(take) then return false end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return false end
  -- Un take con audio tiene una fuente con samples
  return reaper.GetMediaSourceNumSamples(src) > 0
end

local function verify_freezes(freeze_tracks)
  local empty = {}
  for _, t in ipairs(freeze_tracks) do
    if not reaper.ValidatePtr(t, "MediaTrack*") then return end
    local ok = false
    for i = 0, reaper.CountTrackMediaItems(t) - 1 do
      if item_has_audio(reaper.GetTrackMediaItem(t, i)) then
        ok = true
        break
      end
    end
    if not ok then
      local _, name = reaper.GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
      empty[#empty + 1] = name or "?"
    end
  end
  if #empty > 0 then
    reaper.ShowMessageBox(
      "Sin audio grabado en: " .. table.concat(empty, ", ") ..
      "\nRevisa el ruteo ReaInsert y las conexiones de entrada.",
      "AUTO FREEZE", 0)
  else
    reaper.ShowMessageBox("Freeze OK: todas las pistas tienen audio.", "AUTO FREEZE", 0)
  end
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
local function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local track_count = reaper.CountTracks(0)
  local targets = {}

  for i = 0, track_count - 1 do
    local tr = reaper.GetTrack(0, i)
    if has_active_reainsert(tr) then
      targets[#targets + 1] = { track = tr, idx = i }
    end
  end

  if #targets == 0 then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox("No se encontraron pistas con ReaInsert activo.", "AUTO FREEZE", 0)
    reaper.Undo_EndBlock("AUTO FREEZE ReaInsert (none)", -1)
    return
  end

  local freeze_tracks = {}

  -- Procesar de abajo hacia arriba para no invalidar índices
  for i = #targets, 1, -1 do
    local e = targets[i]
    local f = freeze_track(e.track, e.idx)
    freeze_tracks[#freeze_tracks + 1] = f
  end

  -- Seleccionar FREEZE tracks
  reaper.Main_OnCommand(40297, 0)
  for _, t in ipairs(freeze_tracks) do
    reaper.SetTrackSelected(t, true)
  end

  -- Guardar estado de transporte antes de grabarlo
  save_transport_state()

  reaper.PreventUIRefresh(-1)

  -- Ir al inicio y grabar
  reaper.SetEditCurPos(0, true, false)
  reaper.Main_OnCommand(1013, 0)  -- Transport: Record

  -- Verificación diferida tras grabar
  if VERIFY_RECORDING then
    local checks = 0
    local function poll()
      checks = checks + 1
      local bits = reaper.GetPlayStateEx(0)
      local playing = math.floor(bits % 2) == 1
      local recording = math.floor(bits / 2) % 2 == 1

      if recording and STOP_AFTER_ITEM then
        -- print punch: detener al grabar el primer ítem (tras un beat de margen)
        for _, t in ipairs(freeze_tracks) do
          if reaper.CountTrackMediaItems(t) > 0 then
            reaper.Main_OnCommand(1016, 0)  -- Transport: Stop
            break
          end
        end
      end

      if not recording and not playing then
        restore_transport_state()
        verify_freezes(freeze_tracks)
      elseif checks < 600 then
        reaper.defer(poll)
      end
    end
    reaper.defer(poll)
  end

  reaper.Undo_EndBlock("AUTO FREEZE ReaInsert (FINAL)", -1)
end

main()
