-- Plain-Lua stand-ins for what city_orgs' pure modules need, so they run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

-- luajit is Lua 5.1: the 5.3+ pieces the shared modules use
math.tointeger = math.tointeger or function(value)
    if type(value) ~= 'number' or value % 1 ~= 0 then return nil end
    return value
end

-- config.lua uses vectors
function vec3(x, y, z) return { x = x, y = y, z = z } end
function vec4(x, y, z, w) return { x = x, y = y, z = z, w = w } end

local modules = {}

-- ox_lib's require: modules by dotted path from the resource folder
function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

-- config.lua sets the global Config
assert(loadstring(assert(io.open(root .. '/config.lua')):read('*a'), 'config'))()

function check(condition, message)
    if not condition then error(message or 'check failed', 2) end
end

function near(a, b, message)
    check(math.abs(a - b) < 1e-6, ('%s: %s ~= %s'):format(message or 'near', tostring(a), tostring(b)))
end
