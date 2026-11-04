dofile('harness.lua')
Config.SearchDistance = 3.0
Config.SearchJobTypes = { leo = true }
Config.SearchStaffAce = 'admin'

-- Positions on a line, with the vector maths FiveM has. Userdata, because LuaJIT ignores __len on tables.
local xs = setmetatable({}, { __mode = 'k' })

local function vector(x)
    local v = newproxy(true)
    local meta = getmetatable(v)
    meta.__sub = function(a, b) return vector(xs[a] - xs[b]) end
    meta.__len = function(a) return math.abs(xs[a]) end
    xs[v] = x

    return v
end

local positions, states, aces, optin, qbxPlayers, sent = {}, {}, {}, {}, {}, {}

GetPlayerPed = function(src) return src end
GetEntityCoords = function(ped) return vector(positions[ped]) end
GetPlayerName = function(src) return ('player%s'):format(src) end
Player = function(src) return { state = states[src] or {} } end
IsPlayerAceAllowed = function(src, ace) return aces[tonumber(src)] == ace end
TriggerClientEvent = function(name, src, ...) sent[#sent + 1] = { name = name, src = src, args = { ... } } end

exports = {
    qbx_core = {
        GetPlayer = function(_, src) return qbxPlayers[src] end,
        IsOptin = function(_, src) return optin[src] == true end,
    },
}

local function addPlayer(src, x, job, metadata)
    positions[src] = x
    qbxPlayers[src] = {
        PlayerData = {
            source = src,
            job = job or { type = 'none', onduty = false },
            metadata = metadata or {},
            charinfo = { firstname = 'P', lastname = tostring(src) },
        },
    }
end

-- server.players and server.hooks stand-ins: every player is loaded, no hooks refuse
local inventories, viewers = {}, {}
local playersStub = {
    get = function(src) return inventories[src] end,
    viewers = function(src) viewers[src] = viewers[src] or {} return viewers[src] end,
}
local hookResult = true
local realRequire = require
require = function(m)
    if m == 'server.players' then return playersStub end
    if m == 'server.hooks' then return { run = function() return hookResult end } end
    return realRequire(m)
end

local searches = require 'server.searches'

for src = 1, 6 do inventories[src] = { slotCount = 50, maxWeight = 85000, weight = 0, items = {} } end

addPlayer(1, 0)                                          -- a citizen
addPlayer(2, 1)                                          -- a citizen next to them
addPlayer(3, 2, { type = 'leo', onduty = true })         -- police on duty
addPlayer(4, 1, { type = 'leo', onduty = false })        -- police off duty
addPlayer(5, 500)                                        -- staff, far away
addPlayer(6, 2, nil, { ishandcuffed = true })            -- cuffed
aces[5] = 'admin'

-- Not themselves, not nobody
assert(select(2, searches.open(1, 1)) == 'no_player')
assert(select(2, searches.open(1, 99)) == 'no_player')
assert(select(2, searches.open(1, 'x')) == 'no_player')

-- A citizen can't search someone who isn't helpless
assert(select(2, searches.open(1, 2)) == 'no_access')
-- Police off duty count as a citizen
assert(select(2, searches.open(4, 2)) == 'no_access')

-- Police on duty can, when close
assert(searches.open(3, 2) == true and viewers[2][3])
assert(sent[#sent].name == 'city_inventory:client:openOther' and sent[#sent].args[1].label == 'P 2')
positions[3] = 10
assert(select(2, searches.open(3, 1)) == 'too_far')

-- Walking away closes the search on the next move
assert(searches.session(3) == nil and not searches.hasSession(3) and not viewers[2][3])
assert(sent[#sent].name == 'city_inventory:client:closeOther' and sent[#sent].args[1] == 'search_closed')
positions[3] = 2

-- Anyone can rob a cuffed player, or one with their hands up, until that stops
assert(searches.open(1, 6) == true and searches.session(1) == inventories[6])
qbxPlayers[6].PlayerData.metadata.ishandcuffed = false
assert(searches.session(1) == nil)
states[2] = { handsup = true }
assert(searches.open(1, 2) == true)
states[2].handsup = false
assert(searches.session(1) == nil)

-- Staff only on admin duty, then from anywhere
assert(select(2, searches.open(5, 1)) == 'too_far')
optin[5] = true
assert(searches.open(5, 1) == true and searches.session(5) == inventories[1])

-- Opening another closes the first
assert(searches.open(5, 2) == true and not viewers[1][5] and viewers[2][5])

-- A script's openInventory hook can refuse police and robbers, not staff
hookResult = false
assert(select(2, searches.open(3, 2)) == 'no_access')
assert(searches.open(5, 3) == true)

-- The target leaving ends it
inventories[3] = nil
assert(searches.session(5) == nil)
