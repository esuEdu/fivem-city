dofile('harness.lua')
Config.StashDistance = 5.0
local handlers = {}
AddEventHandler = function(name, fn) handlers[name] = fn end
GetInvokingResource = function() return 'test' end
lib.print.error = print
-- storage stub (server.storage is required by stashes)
local db = {}
package.loaded = package.loaded or {}
local storageStub = { load = function(key) return db[key] end, save = function(rows) for _, r in ipairs(rows) do db[r.owner] = r.entries end end }
local realRequire = require
require = function(m) if m == 'server.storage' then return storageStub end return realRequire(m) end
promise = { new = function() return { resolve = function() end } end }
Citizen = { Await = function() end }

local Items = require 'shared.items'
local weightOf = require 'shared.weight'
local Inventory = require 'server.inventory'
local function total(inv) local w = 0 for _, it in pairs(inv.items) do w = w + weightOf(it) end return w end
local function check(...) for _, inv in ipairs({ ... }) do assert(inv.weight == total(inv)) end end

local p = Inventory.new('P', 5, 5000)
local s = Inventory.new('S', 5, 1500)
assert(p:add('water', 2)); assert(p:add('WEAPON_PISTOL', 1))  -- slots 1,2 ; water 500 each? 
local water = Items.water.weight
-- empty target, partial
assert(Inventory.transfer(p, 1, s, 3, 1)); assert(p.items[1].count == 1 and s.items[3].count == 1); check(p, s)
-- stack onto same item
assert(Inventory.transfer(p, 1, s, 3)); assert(p.items[1] == nil and s.items[3].count == 2); check(p, s)
-- bad slots / counts
assert(select(2, Inventory.transfer(p, 9, s, 1)) == 'invalid_slot')
assert(select(2, Inventory.transfer(p, 2, s, 99)) == 'invalid_slot')
assert(select(2, Inventory.transfer(s, 3, p, 1, 5)) == 'invalid_count')
assert(select(2, Inventory.transfer(s, 3, p, 1, 1.5)) == 'invalid_count')
-- swap whole stacks
assert(Inventory.transfer(p, 2, s, 3)); assert(p.items[2].name == 'water' and s.items[3].name == 'WEAPON_PISTOL'); check(p, s)
-- partial onto a different item: slot_occupied
assert(p:add('sandwich', 3)) ; local sw = 1
assert(p.items[sw].name == 'sandwich')
assert(select(2, Inventory.transfer(p, sw, s, 3, 1)) == 'slot_occupied')
-- too heavy for the target
local tiny = Inventory.new('T', 5, water)
assert(select(2, Inventory.transfer(p, 2, tiny, 1)) == 'inventory_full'); assert(p.items[2].count == 2); check(p, tiny)
assert(Inventory.transfer(p, 2, tiny, 1, 1)); check(p, tiny)
-- swap too heavy for the source side
local light = Inventory.new('L', 5, Items.sandwich.weight * 3)
assert(light:add('sandwich', 3))
local heavy = Inventory.new('H', 5, 100000); assert(heavy:add('WEAPON_PISTOL', 1))
assert(select(2, Inventory.transfer(light, 1, heavy, 1)) == 'inventory_full'); check(light, heavy)
-- same inventory falls back to move
assert(Inventory.transfer(s, 3, s, 5)); assert(s.items[5].name == 'WEAPON_PISTOL'); check(s)

-- hooks
local hooks = require 'server.hooks'
local seen
local id = hooks.register('openInventory', function(payload) seen = payload.inventoryId return payload.source == 1 end, { inventoryFilter = { '^house_' } }, 'props')
assert(hooks.run('openInventory', { source = 2, inventoryId = 'policelocker:ABC' }) and seen == nil)  -- filter skips
assert(hooks.run('openInventory', { source = 2, inventoryId = 'house_x:ABC' }) == false and seen == 'house_x:ABC')
assert(hooks.run('openInventory', { source = 1, inventoryId = 'house_x:ABC' }) == true)
hooks.register('openInventory', function() error('boom') end, nil, 'broken')
assert(hooks.run('openInventory', { source = 1, inventoryId = 'x' }) == false)
handlers.onResourceStop('broken')
assert(hooks.run('openInventory', { source = 1, inventoryId = 'x' }) == true)
hooks.remove('props', id)
assert(hooks.run('openInventory', { source = 2, inventoryId = 'house_x:ABC' }) == true)

-- stash ids and loading
vec3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __type = 'vector3' }) end
local stashes = require 'server.stashes'
stashes.register('shared', 'Shared', 10, 5000)
stashes.register('locker', 'Locker', 10, 5000, true, 'police')
stashes.register('house_a', 'House', 10, 5000, 'CID9')
local a = stashes.get('shared'); assert(a and a.id == 'shared' and a.owner == 'stash:shared' and a.type == 'stash')
assert(stashes.get('shared') == a)                          -- cached
assert(stashes.get('locker') == nil)                        -- needs an owner
local l = stashes.get('locker', 'CID1'); assert(l.id == 'locker:CID1')
assert(stashes.get('locker:CID1') == l)                     -- full inventory id works too
local h = stashes.get('house_a'); assert(h.id == 'house_a:CID9' and h.owner == 'stash:house_a:CID9')
assert(stashes.get('nope') == nil and stashes.get(5) == nil)
db['stash:shared2'] = { { slot = 1, name = 'water', count = 3 } }
stashes.register('shared2', 'S2', 4, 9999)
assert(stashes.get('shared2').items[1].count == 3)
-- exports resolver
local inventories = require 'server.inventories'
assert(inventories.resolve('shared') == a and inventories.resolve({ id = 'locker', owner = 'CID1' }) == l)
-- save + evict
assert(a:add('water', 1)); stashes.saveAll()
assert(db['stash:shared'][1].name == 'water')
assert(stashes.get('shared') ~= a)                          -- evicted after save, reloaded from db
print('all stash tests passed')
