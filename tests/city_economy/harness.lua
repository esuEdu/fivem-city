-- Plain-Lua stand-ins for what city_economy's pure modules need, so they run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

-- Lua 5.4 function LuaJIT doesn't have; same rules: only numbers with no fraction (NaN and inf fail)
math.tointeger = math.tointeger or function(value)
    if type(value) == 'number' and value == math.floor(value) and value ~= math.huge and value ~= -math.huge then
        return value
    end
end

local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')

    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

local failures = 0

function check(condition, message)
    if not condition then
        failures = failures + 1
        print('FAIL: ' .. message)
    end
end

function finish()
    if failures > 0 then os.exit(1) end
end
