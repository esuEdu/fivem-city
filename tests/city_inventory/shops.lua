dofile('harness.lua')
Config.ShopDistance = 5.0
Config.ShopAccounts = { 'cash', 'bank' }
-- LuaJIT ignores __len on tables, so vectors are userdata like in FiveM
local data = setmetatable({}, { __mode = 'k' })
local proto = newproxy(true)
local V = getmetatable(proto)
V.__index = function(u, k) return data[u][k] end
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vec3 = function(x, y, z) local u = newproxy(proto) data[u] = { x = x, y = y, z = z } return u end
local realType = type
type = function(v) if realType(v) == 'userdata' and data[v] then return 'vector3' end return realType(v) end
local pos = vec3(0, 0, 0)
GetPlayerPed = function() return 1 end
GetEntityCoords = function() return pos end
local sent = {}
TriggerClientEvent = function(name, src, data) sent[#sent + 1] = { name = name, src = src, data = data } end
GetInvokingResource = function() return 'test' end
local money = { cash = 100, bank = 1000 }
local player = { PlayerData = { job = { name = 'police', grade = { level = 1 } }, gang = { name = 'none', grade = { level = 0 } }, metadata = { licences = { weapon = false } }, charinfo = { firstname = 'Ana', lastname = 'Silva' } } }
exports = { qbx_core = {
    GetPlayer = function() return player end,
    GetMoney = function(_, _, account) return money[account] end,
    RemoveMoney = function(_, _, account, amount) money[account] = money[account] - amount return true end,
    AddMoney = function(_, _, account, amount) money[account] = money[account] + amount return true end,
} }
setmetatable(exports.qbx_core, { __index = function() end })
-- exports.qbx_core:Fn(...) passes self first
for k, fn in pairs(exports.qbx_core) do exports.qbx_core[k] = function(self, ...) return fn(self, ...) end end

local Items = require 'shared.items'
local Inventory = require 'server.inventory'
local search = require 'shared.search'
local shops = require 'server.shops'

-- built-in shops loaded from data/shops.lua with every item defined
for name, data in pairs(require 'data.shops') do
    for _, entry in ipairs(data.inventory) do assert(Items[entry.name], name .. ': ' .. entry.name) end
end

shops.register('Test', {
    name = 'Test Shop', groups = { police = 0 },
    inventory = {
        { name = 'water', price = 10 },
        { name = 'sandwich', price = 5, count = 3 },
        { name = 'WEAPON_PISTOL', price = 50, metadata = { registered = true, serial = 'POL' }, license = 'weapon' },
        { name = 'WEAPON_KNIFE', price = 0, grade = 2 },
        { name = 'lockpick', price = 4, currency = 'black_money' },
        { name = 'not_an_item', price = 1 },
    },
    locations = { vec3(0, 0, 0), vec3(100, 0, 0) },
})
local inv = Inventory.new('C', 10, 100000)

-- groups and distance
player.PlayerData.job.name = 'mechanic'
assert(select(2, shops.open(1, 'Test', 1)) == 'no_access')
player.PlayerData.job.name = 'police'
assert(select(2, shops.open(1, 'Test', 2)) == 'too_far')
assert(select(2, shops.open(1, 'Nope', 1)) == 'no_shop')
assert(shops.open(1, 'Test', 1))
local open = sent[#sent].data
assert(open.kind == 'shop' and open.slots == 5 and open.items[2].stock == 3 and open.items[1].price == 10)

-- buying with cash, then bank
assert(shops.buy(1, inv, 1, 4, 3)); assert(inv.items[4].name == 'water' and inv.items[4].count == 3 and money.cash == 70)
assert(shops.buy(1, inv, 1, nil, 8)); assert(money.cash == 70 and money.bank == 920)  -- 80 > cash -> bank
money.bank = 0
assert(select(2, shops.buy(1, inv, 1, nil, 8)) == 'cannot_afford')
money.bank = 1000
-- stock
assert(shops.buy(1, inv, 2, nil, 2)); assert(sent[#sent].name == 'city_inventory:client:updateOther' and sent[#sent].data[2].stock == 1)
assert(select(2, shops.buy(1, inv, 2, nil, 2)) == 'out_of_stock')
-- licence
assert(select(2, shops.buy(1, inv, 3)) == 'no_license')
player.PlayerData.metadata.licences.weapon = true
assert(shops.buy(1, inv, 3, nil, 5))  -- weapons one at a time
local pistols = search.slots(inv.items, 'WEAPON_PISTOL'); assert(#pistols == 1)
local m = inv.items[pistols[1]].metadata
assert(m.registered == 'Ana Silva' and m.serial:sub(1, 3) == 'POL' and #m.serial > 3)
-- grade
assert(select(2, shops.buy(1, inv, 4)) == 'no_access')
player.PlayerData.job.grade.level = 2
assert(shops.buy(1, inv, 4))
-- item currency
assert(select(2, shops.buy(1, inv, 5, nil, 2)) == 'cannot_afford')
assert(inv:add('black_money', 10)); assert(shops.buy(1, inv, 5, nil, 2)); assert(search.count(inv.items, 'black_money') == 2)
-- bad input
assert(select(2, shops.buy(1, inv, 99)) == 'invalid_slot')
assert(select(2, shops.buy(1, inv, 1, nil, 0)) == 'invalid_slot')
assert(select(2, shops.buy(1, inv, 1, nil, 1.5)) == 'invalid_slot')
assert(select(2, shops.buy(1, inv, 'x')) == 'invalid_slot')
-- full inventory: nothing is paid
local tiny = Inventory.new('T', 1, 100000); assert(tiny:add('phone', 1))
local cash = money.cash
assert(select(2, shops.buy(1, tiny, 1)) == 'inventory_full' and money.cash == cash)
-- walking away closes it
pos = vec3(50, 0, 0)
assert(select(2, shops.buy(1, inv, 1)) == 'stash_closed' and shops.session(1) == nil)
assert(select(2, shops.buy(1, inv, 1)) == 'stash_closed')
print('all shop tests passed')
