-- Plain-Lua stand-ins for what city_fishing's pure modules need, so they run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

math.tointeger = function(value)
    if type(value) == 'number' and value == math.floor(value) then return value end
end

vec3 = function(x, y, z) return { x = x, y = y, z = z } end
vector3 = vec3

Config = {}

local modules = {}

-- ox_lib's require: modules by dotted path from the resource folder, with backtick hashes turned into strings
function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    source = source:gsub('`([^`]+)`', '"%1"')

    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

---A random source that returns the given values in turn (then repeats the last).
---@param values number[]
---@return function
function sequence(values)
    local i = 0

    return function()
        i = math.min(i + 1, #values)
        return values[i]
    end
end

function check(condition, message)
    if not condition then error(message or 'check failed', 2) end
end
