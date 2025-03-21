--[[
 * ReaScript Name: Estructura completa con comprobación de pistas existentes (sin duplicar sends)
 * Description:
 *   Si las pistas con los nombres especificados ya existen, se actualizan sus ruteos, paneo y configuración
 *   sin crear duplicados de envíos. La estructura es:
 *     - Bus "B" (color morado)
 *         - Sub-buses "GDRUM" y "NY" (ruteados a "B")
 *     - Pistas en "GDRUM": "BOMBO", "SNARE_TOP", "SNARE_BOTTOM" y "CAJA" (sin Main Output),
 *         con "BOMBO" y "CAJA" con envío extra a "NY".
 *     - Bus "OH" (sin Main Output, ruteado a "GDRUM") con dentro "OHL" (paneado -1.0) y "OHR" (paneado 1.0).
 *     - Bus "TOMS" (sin Main Output, ruteado a "GDRUM" y a "NY") con dentro "TOM1" (paneado -0.70),
 *       "TOM2" (paneado 0.20) y "TOM3" (paneado 0.70).
 *     - La pista "ROOM" se genera o actualiza y se mueve al final, ruteada a "GDRUM".
 * Author: Patricio Maripani Navarro
 * Licence: Public Domain
 * Version: 1.7
--]]

-------------------------------------------------------------------------------
-- CONFIGURACIÓN
-------------------------------------------------------------------------------
-- Color morado (RGB: 128, 0, 128)
local purpleColor = reaper.ColorToNative(128, 0, 128)

-------------------------------------------------------------------------------
-- FUNCIONES AUXILIARES
-------------------------------------------------------------------------------

-- Crea una pista al final y le asigna nombre y color morado
local function insertTrack(name)
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  reaper.SetTrackColor(tr, purpleColor)
  return tr
end

-- Busca una pista por nombre; si existe, la devuelve (y le pone color morado), si no, la crea.
local function getOrCreateTrack(name)
  local count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if tname == name then
      reaper.SetTrackColor(tr, purpleColor) -- Asegura color morado
      return tr
    end
  end
  return insertTrack(name)
end

-- Asegura que exista un envío desde 'source' a 'dest'. 
-- Si ya existe, no hace nada; si no existe, lo crea.
local function ensureSend(source, dest)
  local sendCount = reaper.GetTrackNumSends(source, 0) -- 0 = sends
  for i = 0, sendCount - 1 do
    local trackDest = reaper.GetTrackSendInfo_Value(source, 0, i, "P_DESTTRACK")
    if trackDest == dest then
      return -- El envío ya existe, no duplicar
    end
  end
  reaper.CreateTrackSend(source, dest)
end

-- Configura una pista desactivando su envío a Main y estableciendo paneo si se especifica
local function configureTrack(tr, pan)
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0) -- desactiva envío a Master
  if pan then
    reaper.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
  end
end

-------------------------------------------------------------------------------
-- PROGRAMA PRINCIPAL
-------------------------------------------------------------------------------
function main()
  -- Bus B
  local trackB = getOrCreateTrack("B")
  
  -- Sub-buses GDRUM y NY, ruteados a B
  local trackGDRUM = getOrCreateTrack("GDRUM")
  local trackNY    = getOrCreateTrack("NY")
  ensureSend(trackGDRUM, trackB)
  ensureSend(trackNY, trackB)
  
  -- Pistas en GDRUM (excepto ROOM)
  local trackBOMBO = getOrCreateTrack("BOMBO")
  configureTrack(trackBOMBO)
  ensureSend(trackBOMBO, trackGDRUM)
  ensureSend(trackBOMBO, trackNY)  -- envío extra a NY
  
  local trackSNARE_TOP = getOrCreateTrack("SNARE_TOP")
  configureTrack(trackSNARE_TOP)
  ensureSend(trackSNARE_TOP, trackGDRUM)
  
  local trackSNARE_BOTTOM = getOrCreateTrack("SNARE_BOTTOM")
  configureTrack(trackSNARE_BOTTOM)
  ensureSend(trackSNARE_BOTTOM, trackGDRUM)
  
  local trackCAJA = getOrCreateTrack("CAJA")
  configureTrack(trackCAJA)
  ensureSend(trackCAJA, trackGDRUM)
  ensureSend(trackCAJA, trackNY)   -- envío extra a NY
  
  -- Bus OH, sin Main Output, ruteado a GDRUM
  local trackOH = getOrCreateTrack("OH")
  configureTrack(trackOH)
  ensureSend(trackOH, trackGDRUM)
  
  -- Dentro de OH: OHL (paneo -1.0) y OHR (paneo 1.0)
  local trackOHL = getOrCreateTrack("OHL")
  configureTrack(trackOHL, -1.0)
  ensureSend(trackOHL, trackOH)
  
  local trackOHR = getOrCreateTrack("OHR")
  configureTrack(trackOHR, 1.0)
  ensureSend(trackOHR, trackOH)
  
  -- Bus TOMS, sin Main Output, ruteado a GDRUM y a NY
  local trackTOMS = getOrCreateTrack("TOMS")
  configureTrack(trackTOMS)
  ensureSend(trackTOMS, trackGDRUM)
  ensureSend(trackTOMS, trackNY)
  
  -- Dentro de TOMS: TOM1, TOM2 y TOM3
  local trackTOM1 = getOrCreateTrack("TOM1")
  configureTrack(trackTOM1, -0.70)
  ensureSend(trackTOM1, trackTOMS)
  
  local trackTOM2 = getOrCreateTrack("TOM2")
  configureTrack(trackTOM2, 0.20)
  ensureSend(trackTOM2, trackTOMS)
  
  local trackTOM3 = getOrCreateTrack("TOM3")
  configureTrack(trackTOM3, 0.70)
  ensureSend(trackTOM3, trackTOMS)
  
  -- Generar o actualizar la pista ROOM y moverla al final
  local trackROOM = getOrCreateTrack("ROOM")
  configureTrack(trackROOM)
  ensureSend(trackROOM, trackGDRUM)
  
  -- Seleccionar ROOM como única pista seleccionada y moverla al final usando el comando de acción.
  reaper.SetOnlyTrackSelected(trackROOM)
  reaper.Main_OnCommand(40635, 0)  -- "Track: Move selected tracks to bottom of track list"
end

reaper.defer(main)
