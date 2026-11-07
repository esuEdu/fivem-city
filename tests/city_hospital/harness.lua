-- Plain-Lua stand-ins for what city_hospital's server modules call, so they run outside the game.
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

-- config.lua uses vec3/vec4 and backtick hashes; tables and strings are enough here
function vec3(x, y, z) return { x = x, y = y, z = z } end
function vec4(x, y, z, w) return { x = x, y = y, z = z, w = w, xyz = vec3(x, y, z) } end

do
    local source = assert(io.open(root .. '/config.lua')):read('*a'):gsub('`([^`]+)`', '"%1"')
    assert(loadstring(source, 'config'))()
end

-- What the modules call on the server, recorded so tests can look at it
Calls = { removeMoney = {}, bills = {}, healed = {} }
BankBalance = 100

clock = 1000
os.time = function() return clock end

function AddEventHandler() end
function GetResourceState() return 'started' end

exports = {
    qbx_core = {
        RemoveMoney = function(_, src, account, amount, reason)
            if amount > BankBalance then return false end
            BankBalance = BankBalance - amount
            Calls.removeMoney[#Calls.removeMoney + 1] = { src = src, amount = amount, reason = reason }
            return true
        end,
    },
    city_bank = {
        CreateBill = function(_, src, amount, label)
            Calls.bills[#Calls.bills + 1] = { src = src, amount = amount, label = label }
            return true
        end,
    },
    qbx_medical = {
        Heal = function(_, src) Calls.healed[#Calls.healed + 1] = src end,
    },
}

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
