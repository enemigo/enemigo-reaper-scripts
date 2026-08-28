-- @description pmn_EXIT Freeze: set ORIGINAL track FX (active) to OFFLINE, disable ORIGINAL routing, ensure FREEZE feeds sends
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Script reversible: guarda el estado previo y permite restaurarlo (MODE = "restore")
--   + Eliminada redundancia: el send de impresión se gestiona según la config, no duplicado
--   + Mensajes de error más claros
-- @about
--   Revierte un freeze con ReaInsert: pone offline los FX activos de la pista original,
--   apaga su ruteo (sends y master send) y deja que la pista FREEZE alimente los sends.
--   El estado previo se guarda en ExtState para poder restaurarlo (MODE = "restore").
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/desarma_freeze.lua

-- === OPTIONS ===
local MODE = "exit"                     -- "exit" = arma el freeze, "restore" = restaura el estado original
local DELETE_PRINT_SEND_INSTEAD_OF_MUTING = false -- true = borra el send original->FREEZE, false = solo lo mutea
local DISARM_FREEZE_TRACKS = true       -- desarma REC en pistas FREEZE
local DISABLE_ORIGINAL_MASTER_SEND = true -- apaga master/parent send en originales
local MUTE_ALL_ORIGINAL_SENDS = true    -- mutea todos los sends en originales
local UNMUTE_ALL_FREEZE_SENDS = true    -- desmutea todos los sends en FREEZE
local ENABLE_FREEZE_MASTER_SEND = true  -- enciende master/parent send en FREEZE

local EXT_SECTION = "enemigo_freeze"
local EXT_KEY = "snapshot"

local function track_index_0based(track)
  local tn = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  if not tn then return nil end
  return math.floor(tn - 1)
end

local function set_active_fx_offline(track, offline)
  local fx_count = reaper.TrackFX_GetCount(track)
  local changed = {}
  for fx = 0, fx_count - 1 do
    local enabled = reaper.TrackFX_GetEnabled(track, fx)
    if enabled and not reaper.TrackFX_GetOffline(track, fx) then
      reaper.TrackFX_SetOffline(track, fx, offline)
      changed[#changed + 1] = fx
    end
  end
  return changed
end

local function set_all_sends_muted(track, mute)
  local send_count = reaper.GetTrackNumSends(track, 0)
  for i = 0, send_count - 1 do
    reaper.SetTrackSendInfo_Value(track, 0, i, "B_MUTE", mute and 1 or 0)
  end
end

--------------------------------------------------------------------------------
-- SNAPSHOT / RESTORE (reversibilidad)
--------------------------------------------------------------------------------
local function snapshot_key()
  local proj = reaper.EnumProjects(-1, "")
  return proj or ""
end

local function save_snapshot(pairs)
  -- pairs: array de { origIdx, freezeIdx, origMainSend, freezeMainSend, freezeRecarm }
  local key = snapshot_key()
  local lines = {}
  for _, p in ipairs(pairs) do
    lines[#lines + 1] = table.concat({
      tostring(p.origIdx),
      tostring(p.freezeIdx),
      tostring(p.origMainSend),
      tostring(p.freezeMainSend),
      tostring(p.freezeRecarm),
    }, ",")
  end
  reaper.SetExtState(EXT_SECTION, EXT_KEY .. key, table.concat(lines, "|"), true)
end

local function load_snapshot()
  local key = snapshot_key()
  local raw = reaper.GetExtState(EXT_SECTION, EXT_KEY .. key)
  if raw == "" then return nil end
  local pairs = {}
  for line in raw:gmatch("[^|]+") do
    local a, b, c, d, e = line:match("(%d+),(%d+),(%d+),(%d+),(%d+)")
    if a then
      pairs[#pairs + 1] = {
        origIdx = tonumber(a),
        freezeIdx = tonumber(b),
        origMainSend = tonumber(c),
        freezeMainSend = tonumber(d),
        freezeRecarm = tonumber(e),
      }
    end
  end
  return pairs
end

local function clear_snapshot()
  reaper.SetExtState(EXT_SECTION, EXT_KEY .. snapshot_key(), "", true)
end

--------------------------------------------------------------------------------
-- EXIT FREEZE
--------------------------------------------------------------------------------
local function do_exit()
  local num_sel = reaper.CountSelectedTracks(0)
  if num_sel == 0 then
    reaper.ShowMessageBox("Selecciona las pistas FREEZE (destino) y ejecuta el script.", "EXIT Freeze", 0)
    return
  end

  local processed = 0
  local pairs = {}

  for i = 0, num_sel - 1 do
    local freeze_tr = reaper.GetSelectedTrack(0, i)
    local idx0 = track_index_0based(freeze_tr)

    if idx0 and idx0 > 0 then
      local orig_tr = reaper.GetTrack(0, idx0 - 1)
      if orig_tr then
        -- Capturar estado original ANTES de mutar (para poder restaurar)
        local origMainSend = reaper.GetMediaTrackInfo_Value(orig_tr, "B_MAINSEND")
        local freezeMainSend = reaper.GetMediaTrackInfo_Value(freeze_tr, "B_MAINSEND")
        local freezeRecarm = reaper.GetMediaTrackInfo_Value(freeze_tr, "I_RECARM")

        set_active_fx_offline(orig_tr, true)

        if MUTE_ALL_ORIGINAL_SENDS then
          set_all_sends_muted(orig_tr, true)
        end
        if DISABLE_ORIGINAL_MASTER_SEND then
          reaper.SetMediaTrackInfo_Value(orig_tr, "B_MAINSEND", 0)
        end

        -- Send de impresión: solo se gestiona si no muteamos todos los sends
        if not MUTE_ALL_ORIGINAL_SENDS then
          local send_count = reaper.GetTrackNumSends(orig_tr, 0)
          for s = send_count - 1, 0, -1 do
            local dest = reaper.GetTrackSendInfo_Value(orig_tr, 0, s, "P_DESTTRACK")
            if dest == freeze_tr then
              if DELETE_PRINT_SEND_INSTEAD_OF_MUTING then
                reaper.RemoveTrackSend(orig_tr, 0, s)
              else
                reaper.SetTrackSendInfo_Value(orig_tr, 0, s, "B_MUTE", 1)
              end
            end
          end
        end

        if UNMUTE_ALL_FREEZE_SENDS then
          set_all_sends_muted(freeze_tr, false)
        end
        if ENABLE_FREEZE_MASTER_SEND then
          reaper.SetMediaTrackInfo_Value(freeze_tr, "B_MAINSEND", 1)
        end

        local freezeRecarmFinal = freezeRecarm
        if DISARM_FREEZE_TRACKS then
          reaper.SetMediaTrackInfo_Value(freeze_tr, "I_RECARM", 0)
          freezeRecarmFinal = 0
        end

        pairs[#pairs + 1] = {
          origIdx = idx0 - 1,
          freezeIdx = idx0,
          origMainSend = origMainSend,
          freezeMainSend = freezeMainSend,
          freezeRecarm = freezeRecarmFinal,
        }
        processed = processed + 1
      end
    end
  end

  if processed == 0 then
    reaper.ShowMessageBox(
      "No pude emparejar FREEZE->Original.\nAsegúrate de que cada FREEZE esté justo debajo de su pista original.",
      "EXIT Freeze", 0)
    return
  end

  save_snapshot(pairs)
end

--------------------------------------------------------------------------------
-- RESTORE (reversibilidad)
--------------------------------------------------------------------------------
local function do_restore()
  local pairs = load_snapshot()
  if not pairs or #pairs == 0 then
    reaper.ShowMessageBox("No hay snapshot guardado de un EXIT Freeze previo.", "EXIT Freeze restore", 0)
    return
  end

  local restored = 0
  for _, p in ipairs(pairs) do
    local orig_tr = reaper.GetTrack(0, p.origIdx)
    local freeze_tr = reaper.GetTrack(0, p.freezeIdx)
    if orig_tr then
      set_active_fx_offline(orig_tr, false)      -- reactivar FX que estaban online
      set_all_sends_muted(orig_tr, false)         -- desmutear sends originales
      reaper.SetMediaTrackInfo_Value(orig_tr, "B_MAINSEND", p.origMainSend)
      if DELETE_PRINT_SEND_INSTEAD_OF_MUTING then
        -- si el send de impresión fue borrado, recrearlo
        if not freeze_tr then return end
        reaper.CreateTrackSend(orig_tr, freeze_tr)
      end
    end
    if freeze_tr then
      set_all_sends_muted(freeze_tr, true)
      reaper.SetMediaTrackInfo_Value(freeze_tr, "B_MAINSEND", p.freezeMainSend)
      reaper.SetMediaTrackInfo_Value(freeze_tr, "I_RECARM", p.freezeRecarm)
    end
    restored = restored + 1
  end

  clear_snapshot()
  reaper.ShowMessageBox(string.format("Restauradas %d pista(s) a su estado original.", restored), "EXIT Freeze restore", 0)
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

if MODE == "restore" then
  do_restore()
else
  do_exit()
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("EXIT Freeze (" .. MODE .. ")", -1)
