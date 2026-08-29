-- @description pmn_Enviar pistas seleccionadas a la primera (sin duplicar envíos y replicando color)
-- @author Patricio Maripani Navarro
-- @version 1.3
-- @changelog
--   + Validación de punteros con ValidatePtr
--   + Reporta cuántas pistas se enrutaron
--   + Opción de aplicar volumen/pánico al send creado
-- @about
--   Con varias pistas seleccionadas, enruta todas a la primera: desactiva su master send,
--   copia el color de la pista destino y crea el envío solo si no existe (no duplica).
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://github.com/enemigo/enemigo-reaper-scripts/raw/main/Scripts/pmn_rutea_a_seleccionado.lua

--[[
 * ReaScript Name: Enviar pistas seleccionadas a la primera (sin duplicar envíos y replicando color)
 * Description:
 *   La primera pista seleccionada se usa como destino. Las demás pistas se enrutan a ella,
 *   se desactiva su envío al Main Output y se les asigna el mismo color que la pista destino.
 *   Si ya existe el envío, no se duplica.
 * Author: Patricio Maripani Navarro
 * Licence: Public Domain
 * Version: 1.2
--]]

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local SEND_VOLUME = nil  -- volumen lineal del send creado (1.0 = 0dB); nil = dejar default
local SEND_PAN    = nil  -- pánico del send creado (-1..1); nil = dejar default

local function isValidTrack(tr)
  return tr and reaper.ValidatePtr(tr, "MediaTrack*") or false
end

function main()
  local num_sel = reaper.CountSelectedTracks(0)
  if num_sel < 2 then
    reaper.ShowMessageBox("Seleccione al menos dos pistas.\nLa primera será el destino.", "Error", 0)
    return
  end

  -- La primera pista seleccionada es el destino
  local dest = reaper.GetSelectedTrack(0, 0)
  if not isValidTrack(dest) then return end

  -- Obtener el color de la pista destino
  local destColor = reaper.GetTrackColor(dest)

  -- Iterar por cada pista seleccionada, exceptuando la primera
  for i = 1, num_sel - 1 do
    local src = reaper.GetSelectedTrack(0, i)
    if isValidTrack(src) then
      -- Copiar el color de la pista destino a la pista fuente
      reaper.SetTrackColor(src, destColor)

      -- Desactivar el envío a Main Output
      reaper.SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)

      -- Verificar si ya existe un envío de src a dest
      local exists = false
      local send_idx = nil
      local num_sends = reaper.GetTrackNumSends(src, 0)
      for j = 0, num_sends - 1 do
        local d = reaper.GetTrackSendInfo_Value(src, 0, j, "P_DESTTRACK")
        if d == dest then
          exists = true
          send_idx = j
          break
        end
      end

      -- Si no existe el envío, crearlo
      if not exists then
        local new_send = reaper.CreateTrackSend(src, dest)
        if SEND_VOLUME then
          reaper.SetTrackSendInfo_Value(src, 0, new_send, "D_VOL", SEND_VOLUME)
        end
        if SEND_PAN then
          reaper.SetTrackSendInfo_Value(src, 0, new_send, "D_PAN", SEND_PAN)
        end
      end
    end
  end

  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Enviar pistas seleccionadas a la primera (sin duplicar envíos y replicando color)", -1)
