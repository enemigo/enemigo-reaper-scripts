-- @description EXIT Freeze: set ORIGINAL track FX (active) to OFFLINE, disable ORIGINAL routing, ensure FREEZE feeds sends
-- @version 1.2
-- @author Reaper DAW Ultimate Assistant

-- === OPTIONS ===
local DELETE_PRINT_SEND_INSTEAD_OF_MUTING = false  -- true = borra el send original->FREEZE, false = solo lo mutea
local DISARM_FREEZE_TRACKS = true                 -- desarma REC en pistas FREEZE
local DISABLE_ORIGINAL_MASTER_SEND = true         -- apaga master/parent send en originales
local MUTE_ALL_ORIGINAL_SENDS = true              -- mutea todos los sends en originales
local UNMUTE_ALL_FREEZE_SENDS = true              -- desmutea todos los sends en FREEZE
local ENABLE_FREEZE_MASTER_SEND = true            -- enciende master/parent send en FREEZE

local function track_index_0based(track)
  local tn = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") -- 1-based
  if not tn then return nil end
  return math.floor(tn - 1)
end

-- Put ACTIVE FX offline on a track (skips already-disabled FX)
local function set_active_fx_offline(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = 0, fx_count - 1 do
    local enabled = reaper.TrackFX_GetEnabled(track, fx)
    if enabled then
      -- offline = true
      reaper.TrackFX_SetOffline(track, fx, true)
    end
  end
end

local function mute_all_sends(track, mute)
  local send_count = reaper.GetTrackNumSends(track, 0) -- 0 = sends
  for i = 0, send_count - 1 do
    reaper.SetTrackSendInfo_Value(track, 0, i, "B_MUTE", mute and 1 or 0)
  end
end

local function handle_print_send(orig_tr, freeze_tr)
  local send_count = reaper.GetTrackNumSends(orig_tr, 0)
  for i = send_count - 1, 0, -1 do
    local dest = reaper.GetTrackSendInfo_Value(orig_tr, 0, i, "P_DESTTRACK")
    if dest == freeze_tr then
      if DELETE_PRINT_SEND_INSTEAD_OF_MUTING then
        reaper.RemoveTrackSend(orig_tr, 0, i)
      else
        reaper.SetTrackSendInfo_Value(orig_tr, 0, i, "B_MUTE", 1)
      end
    end
  end
end

local function main()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local num_sel = reaper.CountSelectedTracks(0)
  if num_sel == 0 then
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox("Selecciona las pistas FREEZE (destino) y ejecuta el script.", "EXIT Freeze", 0)
    reaper.Undo_EndBlock("EXIT Freeze (no selection)", -1)
    return
  end

  local processed = 0

  for i = 0, num_sel - 1 do
    local freeze_tr = reaper.GetSelectedTrack(0, i)
    local idx0 = track_index_0based(freeze_tr)

    if idx0 and idx0 > 0 then
      local orig_tr = reaper.GetTrack(0, idx0 - 1)
      if orig_tr then
        -- ORIGINAL: set active FX offline (includes ReaInsert)
        set_active_fx_offline(orig_tr)

        -- ORIGINAL: disable routing so it no longer feeds the mix/sends
        if MUTE_ALL_ORIGINAL_SENDS then
          mute_all_sends(orig_tr, true)
        end
        if DISABLE_ORIGINAL_MASTER_SEND then
          reaper.SetMediaTrackInfo_Value(orig_tr, "B_MAINSEND", 0)
        end

        -- ORIGINAL: disable/delete the print send to FREEZE
        handle_print_send(orig_tr, freeze_tr)

        -- FREEZE: ensure routing is active
        if UNMUTE_ALL_FREEZE_SENDS then
          mute_all_sends(freeze_tr, false)
        end
        if ENABLE_FREEZE_MASTER_SEND then
          reaper.SetMediaTrackInfo_Value(freeze_tr, "B_MAINSEND", 1)
        end

        if DISARM_FREEZE_TRACKS then
          reaper.SetMediaTrackInfo_Value(freeze_tr, "I_RECARM", 0)
        end

        processed = processed + 1
      end
    end
  end

  reaper.PreventUIRefresh(-1)

  if processed == 0 then
    reaper.ShowMessageBox(
      "No pude emparejar FREEZE->Original.\nAsegúrate de que cada FREEZE esté justo debajo de su pista original.",
      "EXIT Freeze",
      0
    )
  end

  reaper.Undo_EndBlock("EXIT Freeze: originals FX offline + originals routing off + FREEZE feeds sends", -1)
end

main()
