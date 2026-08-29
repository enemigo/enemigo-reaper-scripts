-- @description pmn_Solo bus C (creación si no existe)
-- @noindex
local script_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\][^/\\]*$")
local lib = dofile(script_dir .. "/pmn_solo_bus_lib.lua")

reaper.defer(function() lib.run("C") end)
