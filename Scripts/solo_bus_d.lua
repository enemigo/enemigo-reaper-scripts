-- Solo bus D — acción instalada por el paquete solo_bus_a.lua (no es un paquete propio).
-- @noindex
local script_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\][^/\\]*$")
local lib = dofile(script_dir .. "/solo_bus_lib.lua")

reaper.defer(function() lib.run("D") end)
