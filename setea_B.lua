--[[
 * ReaScript Name: Estructura de mezcla completa con ruteo automático
 * Description:
 * Crea una estructura de ruteo para baterías, reconociendo múltiples micrófonos
 * por instrumento (ej. Kick In/Out). Si las pistas ya existen bajo sus nombres
 * estándar o alias, se actualizan sus ruteos. Al final, crea buses de mezcla,
 * rutea guitarras, voces, bajos e instrumentos a sus respectivos buses y
 * ordena todas las pistas en un orden predefinido.
 * Author: Patricio Maripani Navarro (Modificado por Gemini)
 * Licence: Public Domain
 * Version: 4.0
--]]

-------------------------------------------------------------------------------
-- CONFIGURACIÓN DE ALIAS
-------------------------------------------------------------------------------
local trackAliases = {
    -- Se manejan dos bombos de forma independiente
    KICK_IN       = {"kick_in", "bombo_in", "k_in"},
    KICK_OUT      = {"kick_out", "bombo_out", "k_out"},
    SNARE_TOP     = {"snare_top", "snare", "snare_up", "caja_arriba", "caja", "snare sample", "snare trg"},
    -- Se agrega "snare_bot" para reconocer la pista del usuario
    SNARE_BOTTOM  = {"snare_bottom", "snare_down", "caja_abajo", "snare_bot"},
    SNARE_REV     = {"snare_rev", "reverb caja"},
    OHL           = {"ohl", "oh l", "overhead l"},
    OHR           = {"ohr", "oh r", "overhead r"},
    TOM1          = {"tom1", "t1", "tom 1"},
    TOM2          = {"tom2", "t2", "tom 2"},
    TOM3          = {"tom3", "t3", "tom 3"},
    ROOM          = {"room", "sala", "ambiente", "room_chil"}, -- Se añade alias para "ROOM_CHIL"
    -- Se agrega "room_com" para reconocer el typo común
    ROOM_COMP     = {"room_comp", "room c", "sala comp", "room_com"}
}


-------------------------------------------------------------------------------
-- CONFIGURACIÓN GENERAL
-------------------------------------------------------------------------------
-- Color morado para la batería (RGB: 128, 0, 128)
local purpleColor = reaper.ColorToNative(128, 0, 128)
-- Color gris claro para los grupos A,C,D (RGB: 200, 200, 200)
local greyColor = reaper.ColorToNative(200, 200, 200)
-- Color azul claro para los buses de voz (RGB: 173, 216, 230)
local blueBusColor = reaper.ColorToNative(173, 216, 230)
-- Color azul oscuro para las pistas de voz (RGB: 0, 0, 139)
local blueTrackColor = reaper.ColorToNative(0, 0, 139)
-- Color naranja para las guitarras (RGB: 255, 165, 0)
local orangeColor = reaper.ColorToNative(255, 165, 0)
-- Color rosado para los instrumentos (RGB: 255, 182, 193)
local pinkColor = reaper.ColorToNative(255, 182, 193)
-- Color verde oscuro para los coros (RGB: 0, 100, 0)
local darkGreenColor = reaper.ColorToNative(0, 100, 0)
-- Color amarillo para el bajo (RGB: 255, 255, 0)
local yellowColor = reaper.ColorToNative(255, 255, 0)

-------------------------------------------------------------------------------
-- FUNCIONES AUXILIARES
-------------------------------------------------------------------------------

-- Nueva función para validar si un objeto de pista es válido
local function isValidTrack(tr)
    if tr and reaper.ValidatePtr(tr, "MediaTrack*") then
        return true
    end
    return false
end

-- Crea una pista al final y le asigna nombre y color
local function insertTrack(name, color)
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  if color then
    reaper.SetTrackColor(tr, color)
  end
  return tr
end

-- Busca una pista por su nombre canónico o por una lista de alias (insensible a mayúsculas/minúsculas).
-- Si la encuentra, le pone el nombre canónico y la devuelve.
-- Si no la encuentra, crea una nueva pista con el nombre canónico.
local function getOrCreateTrackByAliases(canonicalName, aliases, color)
  local canonicalNameLower = string.lower(canonicalName)

  -- 1. Buscar una pista existente que coincida
  local count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local tname_lower = string.lower(tname)
      
      -- Primero, buscar coincidencia con el nombre canónico
      if tname_lower == canonicalNameLower then
        if color then reaper.SetTrackColor(tr, color) end -- Asegurar el color
        return tr
      end
      
      -- Segundo, buscar coincidencia con algún alias de la lista
      if aliases then
        for _, alias in ipairs(aliases) do
          if tname_lower == string.lower(alias) then
            reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", canonicalName, true)
            if color then reaper.SetTrackColor(tr, color) end
            return tr
          end
        end
      end
    end
  end
  
  -- 2. Si no se encontró ninguna pista, crear una nueva
  return insertTrack(canonicalName, color)
end


-- Asegura que exista un envío desde 'source' a 'dest'.
local function ensureSend(source, dest)
  if not isValidTrack(source) or not isValidTrack(dest) then return end
  local sendCount = reaper.GetTrackNumSends(source, 0)
  for i = 0, sendCount - 1 do
    local trackDest = reaper.GetTrackSendInfo_Value(source, 0, i, "P_DESTTRACK")
    if trackDest == dest then return end
  end
  reaper.CreateTrackSend(source, dest)
end

-- Configura una pista desactivando su envío a Main y estableciendo paneo si se especifica
local function configureTrack(tr, pan)
  if not isValidTrack(tr) then return end
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
  if pan then
    reaper.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
  end
end

-------------------------------------------------------------------------------
-- FASE FINAL: ORDENAR TODAS LAS PISTAS (se ejecuta en un ciclo separado)
-------------------------------------------------------------------------------
function reorderAllTracks()
    reaper.Undo_BeginBlock()

    -- Primero, deseleccionar todo
    reaper.Main_OnCommand(40289, 0) -- Action: "Track: Unselect all tracks"

    -- 1. Asegurar y ordenar los grupos y buses de voz al principio
    local groupNames = {"A", "B", "C", "D", "VOX", "VDelay", "VRoom", "VHall", "VPlate", "GBV"}
    local vocalBuses = { VOX=true, VDelay=true, VRoom=true, VHall=true, VPlate=true }

    for i = #groupNames, 1, -1 do
        local groupName = groupNames[i]
        local color = greyColor -- Color por defecto para A, C, D
        
        if groupName == "B" then
          color = purpleColor -- "B" es el bus de batería
        elseif vocalBuses[groupName] then
          color = blueBusColor -- Buses de voz
        elseif groupName == "GBV" then
          color = darkGreenColor -- Bus de coros
        end

        local tr = getOrCreateTrackByAliases(groupName, nil, color)
        reaper.SetOnlyTrackSelected(tr)
        reaper.ReorderSelectedTracks(0, 0) -- Mover al índice 0
    end

    -- 2. Buscar todas las pistas de la batería por su nombre final
    local trackMap = {}
    local drumTrackNames = {
        "GDRUM", "NY", "KICK_IN", "KICK_OUT", "SNARE_TOP", "SNARE_BOTTOM", "SNARE_REV",
        "OH", "OHL", "OHR", "TOMS", "TOM1", "TOM2", "TOM3", "ROOM", "ROOM_COMP"
    }
    local trackCount = reaper.CountTracks(0)
    for i = 0, trackCount - 1 do
        local tr = reaper.GetTrack(0, i)
        if isValidTrack(tr) then
            local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            for _, nameToFind in ipairs(drumTrackNames) do
                if tname == nameToFind then
                    trackMap[nameToFind] = tr
                end
            end
        end
    end

    -- 3. Ordenar las pistas de batería después de los grupos
    local targetIdx = #groupNames -- El índice después de todos los buses de grupo.
    for _, trackName in ipairs(drumTrackNames) do
        local trackToMove = trackMap[trackName]
        if trackToMove then
            reaper.SetOnlyTrackSelected(trackToMove)
            reaper.ReorderSelectedTracks(targetIdx, 0)
            targetIdx = targetIdx + 1
        end
    end
    
    -- Deseleccionar todo al final
    reaper.Main_OnCommand(40289, 0) -- Action: "Track: Unselect all tracks"
    reaper.Undo_EndBlock("Ordenar pistas de Batería y Grupos", -1)
end

-------------------------------------------------------------------------------
-- FASE INICIAL: CREAR Y RUTEAR PISTAS
-------------------------------------------------------------------------------
function setupAndRouteTracks()
  reaper.Undo_BeginBlock()

  -- OBTENER O CREAR TODAS LAS PISTAS DE BATERÍA
  local trackB = getOrCreateTrackByAliases("B", nil, purpleColor)
  local trackGDRUM = getOrCreateTrackByAliases("GDRUM", nil, purpleColor)
  local trackNY    = getOrCreateTrackByAliases("NY", nil, purpleColor)
  local trackKICK_IN = getOrCreateTrackByAliases("KICK_IN", trackAliases.KICK_IN, purpleColor)
  local trackKICK_OUT = getOrCreateTrackByAliases("KICK_OUT", trackAliases.KICK_OUT, purpleColor)
  local trackSNARE_TOP = getOrCreateTrackByAliases("SNARE_TOP", trackAliases.SNARE_TOP, purpleColor)
  local trackSNARE_BOTTOM = getOrCreateTrackByAliases("SNARE_BOTTOM", trackAliases.SNARE_BOTTOM, purpleColor)
  local trackSNARE_REV = getOrCreateTrackByAliases("SNARE_REV", trackAliases.SNARE_REV, purpleColor)
  local trackOH = getOrCreateTrackByAliases("OH", nil, purpleColor)
  local trackOHL = getOrCreateTrackByAliases("OHL", trackAliases.OHL, purpleColor)
  local trackOHR = getOrCreateTrackByAliases("OHR", trackAliases.OHR, purpleColor)
  local trackTOMS = getOrCreateTrackByAliases("TOMS", nil, purpleColor)
  local trackTOM1 = getOrCreateTrackByAliases("TOM1", trackAliases.TOM1, purpleColor)
  local trackTOM2 = getOrCreateTrackByAliases("TOM2", trackAliases.TOM2, purpleColor)
  local trackTOM3 = getOrCreateTrackByAliases("TOM3", trackAliases.TOM3, purpleColor)
  local trackROOM = getOrCreateTrackByAliases("ROOM", trackAliases.ROOM, purpleColor)
  local trackROOM_COMP = getOrCreateTrackByAliases("ROOM_COMP", trackAliases.ROOM_COMP, purpleColor)

  -- CONFIGURAR Y RUTEAR BATERÍA
  ensureSend(trackGDRUM, trackB)
  ensureSend(trackNY, trackB)
  configureTrack(trackGDRUM)
  configureTrack(trackNY)
  configureTrack(trackKICK_IN)
  ensureSend(trackKICK_IN, trackGDRUM)
  ensureSend(trackKICK_IN, trackNY)
  configureTrack(trackKICK_OUT)
  ensureSend(trackKICK_OUT, trackGDRUM)
  ensureSend(trackKICK_OUT, trackNY)
  configureTrack(trackSNARE_TOP)
  ensureSend(trackSNARE_TOP, trackGDRUM)
  ensureSend(trackSNARE_TOP, trackNY)
  configureTrack(trackSNARE_BOTTOM)
  ensureSend(trackSNARE_BOTTOM, trackGDRUM)
  configureTrack(trackSNARE_REV)
  ensureSend(trackSNARE_TOP, trackSNARE_REV)
  ensureSend(trackSNARE_REV, trackGDRUM)
  configureTrack(trackOH)
  ensureSend(trackOH, trackGDRUM)
  configureTrack(trackOHL, -1.0)
  ensureSend(trackOHL, trackOH)
  configureTrack(trackOHR, 1.0)
  ensureSend(trackOHR, trackOH)
  configureTrack(trackTOMS)
  ensureSend(trackTOMS, trackGDRUM)
  ensureSend(trackTOMS, trackNY)
  configureTrack(trackTOM1, -0.70)
  ensureSend(trackTOM1, trackTOMS)
  configureTrack(trackTOM2, 0.20)
  ensureSend(trackTOM2, trackTOMS)
  configureTrack(trackTOM3, 0.70)
  ensureSend(trackTOM3, trackTOMS)
  configureTrack(trackROOM)
  ensureSend(trackROOM, trackGDRUM)
  configureTrack(trackROOM_COMP)
  ensureSend(trackROOM_COMP, trackGDRUM)
  reaper.Undo_EndBlock("Crear y rutear estructura de batería", -1)

  -- FASE ADICIONAL: RUTEAR PISTAS DE GUITARRA A GRUPO "C"
  reaper.Undo_BeginBlock()
  local trackC = getOrCreateTrackByAliases("C", nil, greyColor)
  local count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if tname and string.sub(tname, 1, 1):lower() == 'g' then
        if tname:upper() ~= "GDRUM" and tname:upper() ~= "GBV" and reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1 then
          reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
          ensureSend(tr, trackC)
          reaper.SetTrackColor(tr, orangeColor)
        end
      end
    end
  end
  reaper.Undo_EndBlock("Rutear guitarras a Grupo C", -1)

  -- FASE ADICIONAL: RUTEAR PISTAS DE VOZ A GRUPO "VOX"
  reaper.Undo_BeginBlock()
  local trackVOX = getOrCreateTrackByAliases("VOX", nil, blueBusColor)
  local exceptionsVOX = {violin=true, violines=true, viola=true}
  count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if tname and string.sub(tname, 1, 1):lower() == 'v' then
        if not exceptionsVOX[tname:lower()] and tname:upper() ~= "VOX" and reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1 then
          reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
          ensureSend(tr, trackVOX)
          reaper.SetTrackColor(tr, blueTrackColor)
        end
      end
    end
  end
  reaper.Undo_EndBlock("Rutear voces a Grupo VOX", -1)

  -- FASE ADICIONAL: RUTEAR PISTAS DE INSTRUMENTOS A GRUPO "A"
  reaper.Undo_BeginBlock()
  local trackA = getOrCreateTrackByAliases("A", nil, greyColor)
  local instrumentPrefixes = {"piano", "keyboard", "cuerdas", "sintes", "synth", "sintetizador", "pad", "keys", "strings", "rhodes", "wurli", "organ", "organo", "cellos", "cello", "orquesta", "trompetas", "horns", "horn", "rhode"}
  count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if tname and reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1 then
        local tname_lower = tname:lower()
        for _, prefix in ipairs(instrumentPrefixes) do
          if string.sub(tname_lower, 1, #prefix) == prefix then
            reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
            ensureSend(tr, trackA)
            reaper.SetTrackColor(tr, pinkColor)
            break 
          end
        end
      end
    end
  end
  reaper.Undo_EndBlock("Rutear instrumentos a Grupo A", -1)

  -- FASE ADICIONAL: CREAR Y RUTEAR BUSES DE EFECTOS DE VOZ A "VOX"
  reaper.Undo_BeginBlock()
  local trackVOX_for_sends = getOrCreateTrackByAliases("VOX", nil, blueBusColor)
  local trackVDelay = getOrCreateTrackByAliases("VDelay", nil, blueBusColor)
  local trackVRoom = getOrCreateTrackByAliases("VRoom", nil, blueBusColor)
  local trackVHall = getOrCreateTrackByAliases("VHall", nil, blueBusColor)
  local trackVPlate = getOrCreateTrackByAliases("VPlate", nil, blueBusColor)
  ensureSend(trackVDelay, trackVOX_for_sends)
  configureTrack(trackVDelay)
  ensureSend(trackVRoom, trackVOX_for_sends)
  configureTrack(trackVRoom)
  ensureSend(trackVHall, trackVOX_for_sends)
  configureTrack(trackVHall)
  ensureSend(trackVPlate, trackVOX_for_sends)
  configureTrack(trackVPlate)
  reaper.Undo_EndBlock("Crear y rutear buses de efectos de voz", -1)

  -- FASE ADICIONAL: CREAR Y RUTEAR BUS DE COROS "GBV" A GRUPO "A"
  reaper.Undo_BeginBlock()
  local trackA_for_gbv = getOrCreateTrackByAliases("A", nil, greyColor)
  local trackGBV = getOrCreateTrackByAliases("GBV", nil, darkGreenColor)
  ensureSend(trackGBV, trackA_for_gbv)
  configureTrack(trackGBV)
  reaper.Undo_EndBlock("Crear y rutear bus de coros GBV", -1)

  -- FASE ADICIONAL: RUTEAR PISTAS DE COROS A GRUPO "GBV"
  reaper.Undo_BeginBlock()
  local trackGBV_for_bv = getOrCreateTrackByAliases("GBV", nil, darkGreenColor)
  count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if tname and string.sub(tname, 1, 2):lower() == 'bv' then
        if reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1 then
          reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
          ensureSend(tr, trackGBV_for_bv)
          reaper.SetTrackColor(tr, darkGreenColor)
        end
      end
    end
  end
  reaper.Undo_EndBlock("Rutear coros a Grupo GBV", -1)
  
  -- FASE ADICIONAL: RUTEAR PISTAS DE BAJO A GRUPO "B"
  reaper.Undo_BeginBlock()
  local trackB_for_bass = getOrCreateTrackByAliases("B", nil, purpleColor)
  count = reaper.CountTracks(0)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(0, i)
    if isValidTrack(tr) then
      local _, tname = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if tname and string.sub(tname, 1, 4):lower() == 'bajo' then
        if reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1 then
          reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
          ensureSend(tr, trackB_for_bass)
          reaper.SetTrackColor(tr, yellowColor)
        end
      end
    end
  end
  reaper.Undo_EndBlock("Rutear bajos a Grupo B", -1)


  reaper.defer(reorderAllTracks)
end

-------------------------------------------------------------------------------
-- PUNTO DE ENTRADA
-------------------------------------------------------------------------------
reaper.defer(setupAndRouteTracks)

