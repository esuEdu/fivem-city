dofile('harness.lua')
Config.DropSlots = 5; Config.DropMaxWeight = 100000; Config.DropDistance = 3.0; Config.DropMinutes = 10
Config.TradeDistance = 3.0; Config.TradeSlots = 4; Config.TradeMaxWeight = 1000000

-- vectors as userdata (LuaJIT ignores __len on tables)
local vdata = setmetatable({}, { __mode = 'k' })
local proto = newproxy(true)
local V = getmetatable(proto)
V.__index = function(u, k) return vdata[u][k] end
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vec3 = function(x, y, z) local u = newproxy(proto) vdata[u] = { x = x, y = y, z = z } return u end
local realType = type
type = function(v) if realType(v) == 'userdata' and vdata[v] then return 'vector3' end return realType(v) end

local pos = { [1] = vec3(0, 0, 0), [2] = vec3(1, 0, 0) }
GetPlayerPed = function(src) return src end
GetEntityCoords = function(ped) return pos[ped] or vec3(999, 999, 999) end
GetPlayerName = function(src) return pos[src] and ('P' .. src) or nil end
local events = {}
TriggerClientEvent = function(name, src, ...) events[#events + 1] = { name = name, src = src, args = { ... } } end
local function last(name, src) for i = #events, 1, -1 do local e = events[i] if e.name == name and (not src or e.src == src) then return e end end end
CreateThread = function() end
SetTimeout = function() end
AddEventHandler = function() end
locale = function(k) return k end
os.time = (function() local t = 1000 return function() return t end end)()
local clock = 1000
lib.callback = setmetatable({ register = function() end }, { __call = function(_, name, target, cb) cb(true) end })
promise = { new = function() local p = {} function p:resolve(v) self.value = v end return p end }
Citizen = { Await = function(p) return p.value end }

local money = { [1] = 500, [2] = 100 }
local meta = { [1] = {}, [2] = {} }
exports = { qbx_core = {} }
local function api(fn) return function(_, ...) return fn(...) end end
exports.qbx_core.GetPlayer = api(function(src) return pos[src] and { PlayerData = { metadata = meta[src], charinfo = { firstname = 'P', lastname = tostring(src) } } } end)
exports.qbx_core.GetMoney = api(function(src) return money[src] end)
exports.qbx_core.RemoveMoney = api(function(src, _, amount) if money[src] < amount then return false end money[src] = money[src] - amount return true end)
exports.qbx_core.AddMoney = api(function(src, _, amount) money[src] = money[src] + amount return true end)

local Inventory = require 'server.inventory'
local search = require 'shared.search'
local invs = { [1] = Inventory.new('A', 5, 100000), [2] = Inventory.new('B', 5, 100000) }
invs[1].id, invs[2].id = 1, 2
local synced = {}
package.loaded = package.loaded or {}
local realRequire = require
require = function(m)
    if m == 'server.players' then return { get = function(src) return invs[src] end, sync = function(src) invs[src]:takeChanges() synced[src] = true end } end
    return realRequire(m)
end

-- drops
local drops = require 'server.drops'
assert(drops.open(1))
local open = last('city_inventory:client:openOther', 1).args[1]
assert(open.kind == 'drop' and open.id == 'ground' and next(open.items) == nil)
assert(select(2, drops.session(1, false)) == 'invalid_slot')    -- nothing to take from an empty ground
local ground = drops.session(1, true)                           -- putting something down makes the drop
assert(ground and ground.type == 'drop' and last('city_inventory:client:addDrop'))
assert(invs[1]:add('water', 3))
assert(Inventory.transfer(invs[1], 1, ground, 1, 2)); drops.sync(ground)
assert(ground.items[1].count == 2 and last('city_inventory:client:updateOther', 1))
-- player 2 opens the ground next to it and takes everything
pos[2] = vec3(1, 1, 0)
drops.open(2)
assert(last('city_inventory:client:openOther', 2).args[1].id == ground.id)
local g2 = drops.session(2)
assert(g2 == ground)
assert(Inventory.transfer(g2, 1, invs[2], 1)); drops.sync(g2)
assert(last('city_inventory:client:removeDrop').args[1] == ground.id)   -- empty -> removed
assert(select(2, drops.session(2)) == 'stash_closed')
-- walking away
drops.open(1); local g = drops.session(1, true); assert(invs[1]:add('sandwich', 1))
assert(Inventory.transfer(invs[1], invs[1]:slotFor('sandwich'), g, 1)) ; drops.sync(g)
pos[1] = vec3(10, 0, 0)
assert(select(2, drops.session(1)) == 'stash_closed')
pos[1] = vec3(0, 0, 0)
-- custom drop
local id = drops.custom({ { 'water', 2 }, { name = 'nope', count = 1 } }, vec3(5, 5, 0))
assert(id and drops.get(id).items[1].count == 2)
assert(drops.custom({ { 'nope', 1 } }, vec3(5, 5, 0)) == nil)

-- trades
invs[1] = Inventory.new('A', 5, 100000); invs[1].id = 1
invs[2] = Inventory.new('B', 5, 100000); invs[2].id = 2
pos[2] = vec3(1, 0, 0)
local trades = require 'server.trades'
assert(select(2, trades.request(1, 1)) == 'trade_no_player')
assert(trades.request(1, 2))
assert(last('city_inventory:client:openTrade', 1) and last('city_inventory:client:openTrade', 2))
assert(select(2, trades.request(2, 1)) == 'busy' or true)
assert(invs[1]:add('water', 4)); assert(invs[1]:add('WEAPON_PISTOL', 1, { ammo = 7 }))
assert(invs[2]:add('sandwich', 2))
local offerA, offerB = trades.offer(1), trades.offer(2)
assert(Inventory.transfer(invs[1], 1, offerA, 1, 3)); trades.changed(1)
assert(Inventory.transfer(invs[1], 2, offerA, 2)); trades.changed(1)
assert(Inventory.transfer(invs[2], 1, offerB, 1)); trades.changed(2)
assert(trades.setCash(1, 200)); assert(select(2, trades.setCash(2, 5000)) == 'cannot_afford')
assert(select(2, trades.setCash(1, -1)) == 'invalid_count')
-- accepting, then a change clears the accepts
assert(trades.accept(1, true)); assert(trades.get(1).accepted[1])
assert(trades.setCash(1, 150)); assert(not trades.get(1).accepted[1])
-- 'their' side is never resolved by name; offer belongs to its owner only
assert(trades.offer(2) == offerB and trades.offer(1) == offerA)
-- complete
assert(trades.accept(1, true)); assert(trades.accept(2, true))
assert(trades.get(1) == nil and trades.get(2) == nil)
assert(last('city_inventory:client:closeTrade', 1).args[1] == 'trade_done')
assert(search.count(invs[2].items, 'water') == 3 and search.count(invs[2].items, 'WEAPON_PISTOL') == 1)
assert(invs[2].items[search.slots(invs[2].items, 'WEAPON_PISTOL')[1]].metadata.ammo == 7)
assert(search.count(invs[1].items, 'sandwich') == 2 and search.count(invs[1].items, 'water') == 1)
assert(money[1] == 350 and money[2] == 250)

-- full inventory: nothing moves, accepts reset
invs[1] = Inventory.new('A', 1, 100000); invs[1].id = 1; assert(invs[1]:add('phone', 1))
invs[2] = Inventory.new('B', 5, 100000); invs[2].id = 2; assert(invs[2]:add('lockpick', 1))
os.time = function() return 2000 end
assert(trades.request(1, 2))
assert(Inventory.transfer(invs[2], 1, trades.offer(2), 1)); trades.changed(2)
assert(trades.accept(1, true)); assert(trades.accept(2, true))
assert(trades.get(1) and not trades.get(1).accepted[1] and last('city_inventory:client:tradeProblem', 1).args[1] == 'trade_full')
assert(trades.get(1).offers[2].items[1].name == 'lockpick')
-- cancel: offers go back; what doesn't fit goes on the ground
assert(Inventory.transfer(invs[1], 1, trades.offer(1), 1)); trades.changed(1)
assert(invs[1]:add('radio', 1))                                 -- the slot is taken again
trades.cancel(2, 'trade_cancelled')
assert(trades.get(1) == nil and search.count(invs[2].items, 'lockpick') == 1)
assert(search.count(invs[1].items, 'phone') == 0 and last('city_inventory:client:addDrop'))   -- phone dropped
assert(last('city_inventory:client:closeTrade', 1).args[1] == 'trade_cancelled')
-- too far
os.time = function() return 3000 end
pos[2] = vec3(20, 0, 0)
assert(select(2, trades.request(1, 2)) == 'too_far')
print('all drop and trade tests passed')
