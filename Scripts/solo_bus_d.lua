-- @description pmn_Solo bus D (creación si no existe)
-- @noindex
local script_dir = debug.getinfo(1, "S").source:match("@?(.*)[/\\][^/\\]*$")
local lib = dofile(script_dir .. "/solo_bus_lib.lua")

reaper.defer(function() lib.run("D") end)
