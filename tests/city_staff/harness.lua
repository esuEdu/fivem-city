-- Plain-Lua stand-ins for what city_staff gets from FiveM and ox_lib, so its rules run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

math.tointeger = function(value)
    if type(value) == 'number' and value == math.floor(value) then return value end
end

local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

-- The real config, so tests check against the defaults the server ships
local configSource = assert(io.open(root .. '/config.lua')):read('*a')
assert(loadstring(configSource, 'config'))()
