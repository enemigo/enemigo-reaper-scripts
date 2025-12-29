-- @description Auto-freeze tracks with ACTIVE ReaInsert (preserve routing/color), bypass original sends (except FREEZE), go to 0 and RECORD (smart mono/stereo)
-- @version 1.8
-- @author Reaper DAW Ultimate Assistant
-- @requires SWS Extension

local function has_active_reainsert(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = 0, fx_count - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and name and name:match("ReaInsert") then
      if reaper.TrackFX_GetEnabled(track, fx) then return true end
    end
  end
  return false
end

-- Mono decision even if track is 2ch:
-- Mono if: I_NCHAN==1 OR width==0 OR (all audio items mono and no MIDI)
local function should_print_mono(track)
  local nchan = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
  if nchan and nchan <= 1 then return true end

  local width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
  if width and math.abs(width) < 1e-9 then return true end

  local item_count = reaper.CountTrackMediaItems(track)
  if item_count == 0 then return false end

  local saw_audio = false
  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local take = reaper.GetActiveTake(item)
    if take then
      if reaper.TakeIsMIDI(take) then return false end
      local src = reaper.GetMediaItemTake_Source(take)
      if src then
        local ch = reaper.GetMediaSourceNumChannels(src)
        if ch and ch >= 2 then return false end
        if ch and ch == 1 then saw_audio = true end
      end
    end
  end

  return saw_audio
end

-- Copy send parameters properly (string parmnames)
local function copy_send_params(src_tr, src_send_idx, dst_tr, dst_send_idx)
  local keys = {
    "D_VOL",
    "D_PAN",
    "D_PANLAW",
    "B_MUTE",
    "B_PHASE",
    "I_SENDMODE",
    "I_SRCCHAN",
    "I_DSTCHAN",
    "I_MIDIFLAGS",
  }
  for _, k in ipairs(keys) do
    local v = reaper.GetTrackSendInfo_Value(src_tr, 0, src_send_idx, k)
    reaper.SetTrackSendInfo_Value(dst_tr, 0, dst_send_idx, k, v)
  end
end

-- Copy all sends FROM original to freeze (so freeze keeps the same routing)
local function preserve_sends(from_track, to_track)
  local send_count = reaper.GetTrackNumSends(from_track, 0) -- 0 = sends
  for i = 0, send_count - 1 do
    local dest_track = reaper.BR_GetMediaTrackSendInfo_Track(from_track, 0, i, 1)
    if dest_track then
      local new_send = reaper.CreateTrackSend(to_track, dest_track)
      copy_send_params(from_track, i, to_track, new_send)
    end
  end
end

-- Bypass (mute) all existing sends on original track
local function bypass_all_original_sends(track)
  local send_count = reaper.GetTrackNumSends(track, 0)
  for i = 0, send_count - 1 do
    reaper.SetTrackSendInfo_Value(track, 0, i, "B_MUTE", 1)
  end
end

local function freeze_track(track, idx)
  local color       = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
  local master_send = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")
  local nchan       = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")

  -- Insert FREEZE track directly below original
  reaper.InsertTrackAtIndex(idx + 1, true)
  local freeze = reaper.GetTrack(0, idx + 1)

  -- Name
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  reaper.GetSetMediaTrackInfo_String(freeze, "P_NAME", "FREEZE – " .. (name or ""), true)

  -- Copy color / parent send / channel count
  reaper.SetMediaTrackInfo_Value(freeze, "I_CUSTOMCOLOR", color)
  reaper.SetMediaTrackInfo_Value(freeze, "B_MAINSEND", master_send)
  reaper.SetMediaTrackInfo_Value(freeze, "I_NCHAN", nchan)

  -- 1) Copy original sends to FREEZE (so FREEZE keeps the same destination routing)
  preserve_sends(track, freeze)

  -- 2) Bypass routing on ORIGINAL: mute all existing sends and disable master/parent send
  bypass_all_original_sends(track)
  reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)

  -- 3) Create the ONLY active routing on ORIGINAL: send to FREEZE (unmuted)
  local send_to_freeze = reaper.CreateTrackSend(track, freeze)
  reaper.SetTrackSendInfo_Value(track, 0, send_to_freeze, "B_MUTE", 0)
  -- (opcional: aseguras unity)
  reaper.SetTrackSendInfo_Value(track, 0, send_to_freeze, "D_VOL", 1.0)

  -- Arm + monitoring + record output mode (smart mono/stereo)
  reaper.SetMediaTrackInfo_Value(freeze, "I_RECARM", 1)
  reaper.SetMediaTrackInfo_Value(freeze, "I_MONITOR", 1)

  local want_mono = should_print_mono(track)
  reaper.SetMediaTrackInfo_Value(freeze, "I_RECMODE", want_mono and 5 or 1) -- 5 mono out, 1 stereo out

  return freeze
end

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
    reaper.ShowMessageBox("No se encontraron pistas con ReaInsert ACTIVO (no bypass).", "Freeze ReaInsert", 0)
    reaper.Undo_EndBlock("Auto-Freeze ReaInsert (none found)", -1)
    return
  end

  local freeze_tracks = {}

  -- Process bottom->top to keep correct placement
  for i = #targets, 1, -1 do
    local entry = targets[i]
    local new_tr = freeze_track(entry.track, entry.idx)
    freeze_tracks[#freeze_tracks + 1] = new_tr
  end

  -- Select only FREEZE tracks
  reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
  for _, t in ipairs(freeze_tracks) do
    reaper.SetTrackSelected(t, true)
  end

  reaper.PreventUIRefresh(-1)

  -- Scroll to selected
  reaper.Main_OnCommand(40913, 0)

  -- Move cursor to project start and record
  reaper.SetEditCurPos(0, true, false)
  reaper.Main_OnCommand(1013, 0) -- Transport: Record

  reaper.Undo_EndBlock("Auto-Freeze ReaInsert tracks (copy send values + bypass original sends) + go start + REC", -1)
end

main()
