-- Plain-Lua stand-ins for what city_os gets from FiveM and ox_lib, so its logic runs outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

math.tointeger = function(value)
    if type(value) == 'number' and value == math.floor(value) then return value end
end

-- config.lua uses backtick hashes and vector3, which plain Lua doesn't have
vector3 = function(x, y, z) return { x = x, y = y, z = z } end

lib = {
    print = { warn = function() end, info = function() end },
    string = { random = function() return 'KX' end },
}

local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    source = source:gsub('`([^`]+)`', '"%1"')

    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

-- The real config, so tests check against the defaults the server ships
local configSource = assert(io.open(root .. '/config.lua')):read('*a'):gsub('`([^`]+)`', '"%1"')
assert(loadstring(configSource, 'config'))()
