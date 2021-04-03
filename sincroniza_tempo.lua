-- THIS SCRIPT IS A MESSAGE TO KNOW HOW MANY MILISECONDS USE ON DELAYS OR RELEASES

local tempo=reaper.Master_GetTempo()


reaper.ShowMessageBox(
"BPM: "..tempo.."\n"
.."1/1: "..60000/tempo.."\n"
.."1/2: "..60000/(tempo*2).."\n"
.."1/4: "..60000/(tempo*4).."\n"
.."1/8: "..60000/(tempo*8).."\n"
.."1/16: "..60000/(tempo*16).."\n"
.."1/32: "..60000/(tempo*32).."\n"
,'Sincroniza tu tiempo',0)