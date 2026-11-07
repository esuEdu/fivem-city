-- Plain-Lua stand-ins so city_phone_music's server helpers run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>

local root = arg[1]

loadstring = loadstring or load

local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')

    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end

-- What server/common.lua touches when it loads
promise = { new = function() return { state = 0, resolve = function() end } end }
function AddEventHandler() end

assert(loadstring(assert(io.open(root .. '/config.lua')):read('*a'), 'config'))()

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
