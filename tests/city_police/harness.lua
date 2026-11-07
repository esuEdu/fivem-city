-- Plain-Lua stand-ins for what city_police gets from FiveM and ox_lib, so its rules run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

math.tointeger = function(value)
    if type(value) == 'number' and value == math.floor(value) then return value end
end

math.type = function(value)
    if type(value) ~= 'number' then return nil end
    return value == math.floor(value) and 'integer' or 'float'
end

---Reads a resource file; backtick hashes (`model`) become plain strings, which luajit can parse.
---@param path string
---@return string
local function read(path)
    local source = assert(io.open(root .. '/' .. path)):read('*a')
    return (source:gsub('`([^`]*)`', '"%1"'))
end

local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    modules[name] = assert(loadstring(read(name:gsub('%.', '/') .. '.lua'), name))()

    return modules[name]
end

vec3 = function(x, y, z) return { x = x, y = y, z = z } end
vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end

-- The real config, so tests check against the defaults the server ships
assert(loadstring(read('config.lua'), 'config'))()
