-- @description AUTO FREEZE ReaInsert (copy routing, color, MASTER SEND state, smart mono/stereo, go to 0 and RECORD)
-- @version FINAL
-- @author Reaper DAW Ultimate Assistant
-- @requires SWS Extension

-------------------------------------------------------
-- Detect active ReaInsert
-------------------------------------------------------
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

-------------------------------------------------------
-- Smart mono / stereo decision
-------------------------------------------------------
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

-------------------------------------------------------
-- Copy send parameters correctly
-------------------------------------------------------
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

-------------------------------------------------------
-- Copy all sends FROM original TO freeze
-------------------------------------------------------
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

-------------------------------------------------------
-- Freeze one track
-------------------------------------------------------
local function freeze_track(track, idx)
  local color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
  local nchan = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")

  -- ✅ CAPTURAR ESTADO REAL DEL MASTER SEND
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

  -- ✅ FORZAR MASTER SEND AL FINAL
  reaper.SetMediaTrackInfo_Value(freeze, "B_MAINSEND", master_send)

  return freeze
end

-------------------------------------------------------
-- MAIN
-------------------------------------------------------
local function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local track_count = reaper.CountTracks(0)
  local targets = {}

  -- Collect targets first
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

  -- Process bottom → top
  for i = #targets, 1, -1 do
    local e = targets[i]
    local f = freeze_track(e.track, e.idx)
    freeze_tracks[#freeze_tracks + 1] = f
  end

  -- Select FREEZE tracks
  reaper.Main_OnCommand(40297, 0)
  for _, t in ipairs(freeze_tracks) do
    reaper.SetTrackSelected(t, true)
  end

  reaper.PreventUIRefresh(-1)

  -- Go to start and record
  reaper.SetEditCurPos(0, true, false)
  reaper.Main_OnCommand(1013, 0)

  reaper.Undo_EndBlock("AUTO FREEZE ReaInsert (FINAL)", -1)
end

main()
