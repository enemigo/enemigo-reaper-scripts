-- @description pmn_Solo bus (A/B/C/D/VOX): toggle select + solo con creación
-- @author Patricio Maripani Navarro
-- @version 2.0
-- @changelog
--   + Refactorizado a librería compartida (solo_bus_lib.lua)
--   + Un script por bus (A/B/C/D/VOX): cada bus con su propia acción/atajo
--   + Paquete ReaPack único: instala los 5 buses + la librería
-- @about
--   Busca el bus por coincidencia difusa de nombre, lo crea si no existe,
--   des-solo el resto y deja solo ese bus, trayéndolo a la vista.
--   Este paquete instala las acciones de los buses A, B, C, D y VOX.
-- @requires SWS/S&M Extension
-- @provides
--   [nomain] solo_bus_lib.lua
--   [main] solo_bus_b.lua
--   [main] solo_bus_c.lua
--   [main] solo_bus_d.lua
--   [main] solo_bus_vox.lua
-- @website https://github.com/enemigo/enemigo-reaper-scripts
-- @source https://raw.githubusercontent.com/enemigo/enemigo-reaper-scripts/main/Scripts/solo_bus_a.lua

local script_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\][^/\\]*$")
local lib = dofile(script_dir .. "/solo_bus_lib.lua")

reaper.defer(function() lib.run("A") end)
