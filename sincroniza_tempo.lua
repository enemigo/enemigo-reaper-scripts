-- @description Sincroniza tempo: calculadora de ms por división rítmica
-- @author Patricio Maripani Navarro
-- @version 1.0
-- @changelog
--   + Release ReaPack
-- @about
--   Muestra en una caja las duraciones en milisegundos de las divisiones rítmicas
--   (1/1 a 1/32, tercillos y puntillos) al BPM actual del proyecto.
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/sincroniza_tempo.lua

-- THIS SCRIPT IS A MESSAGE TO KNOW HOW MANY MILISECONDS USE ON DELAYS OR RELEASES

local tempo=reaper.Master_GetTempo()

function round(number, precision)
   local fmtStr = string.format('%%0.%sf',precision)
   number = string.format(fmtStr,number)
   return number
end

reaper.ShowMessageBox(
"BPM: "..tempo.."\n"
.."1/1: "..60000/tempo.."\n"
.."1/2: "..60000/(tempo*2).."\n"
.."1/4: "..60000/(tempo*4).."\n"
.."1/8: "..60000/(tempo*8).."\n"
.."1/16: "..60000/(tempo*16).."\n"
.."1/32: "..60000/(tempo*32).."\n"
.."---- tripplet ---- \n"
.."1/1: "..round(60000/(tempo)*(2/3),2).."\n"
.."1/2: "..round(60000/(tempo*2)*(2/3),2).."\n"
.."1/4: "..round(60000/(tempo*4)*(2/3),2).."\n"
.."1/8: "..round(60000/(tempo*8)*(2/3),2).."\n"
.."1/16: "..round(60000/(tempo*16)*(2/3),2).."\n"
.."1/32: "..round(60000/(tempo*32)*(2/3),2).."\n"
.."---- dotted ---- \n"
.."1/1: "..60000/(tempo)*(3/2).."\n"
.."1/2: "..60000/(tempo*2)*(3/2).."\n"
.."1/4: "..60000/(tempo*4)*(3/2).."\n"
.."1/8: "..60000/(tempo*8)*(3/2).."\n"
.."1/16: "..60000/(tempo*16)*(3/2).."\n"
.."1/32: "..60000/(tempo*32)*(3/2).."\n"
,'Sincroniza tu tiempo',0)

