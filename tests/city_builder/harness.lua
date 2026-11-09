-- Plain-Lua stand-ins for city_builder's pure modules, so they run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

local modules = {}

-- ox_lib's require: modules by dotted path from the resource folder
function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

function near(a, b, epsilon)
    return math.abs(a - b) < (epsilon or 1e-6)
end
