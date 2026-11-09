-- Plain-Lua stand-ins for what city_robbery's pure modules need, so they run outside the game.
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

function check(condition, message)
    if not condition then error(message or 'check failed', 2) end
end
