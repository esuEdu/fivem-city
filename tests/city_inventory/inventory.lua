dofile('harness.lua')
local Items = require 'shared.items'
assert(Items.weapon_pistol == Items.WEAPON_PISTOL and Items.WEAPON_PISTOL.name == 'WEAPON_PISTOL')
assert(Items.water.consume == 1 and Items.radio.consume == 0 and Items.radio.event == 'mm_radio:client:use')
assert(Items.sandwich.consume == nil and Items.burger.status.hunger == 200000)
assert(Items['ammo-9'].ammo and Items.WEAPON_PISTOL.ammoname == 'ammo-9' and Items.at_flashlight.category == 'weapon')
local Inventory = require 'server.inventory'
local inv = Inventory.new('CID1', 5, 2000, { { slot = 1, name = 'water', count = 2 }, { slot = 9, name = 'gone', count = 1 } })
assert(inv.weight == 1000 and #inv.unknown == 1)
assert(inv:add('water', 1)); assert(inv.items[1].count == 3 and inv.weight == 1500)
assert(not inv:add('water', 2) == true)            -- overweight
assert(select(2, inv:add('water', 1.5)) == 'invalid_count')
assert(select(2, inv:add('nope', 1)) == 'invalid_item')
assert(inv:add('weapon_knife', 1)); assert(inv.items[2].name == 'WEAPON_KNIFE' and inv.items[2].metadata.serial == 'SER1' and inv.items[2].metadata.ammo == nil)
assert(inv:move(1, 3, 1)); assert(inv.items[1].count == 2 and inv.items[3].count == 1)
assert(inv:move(3, 1)); assert(inv.items[1].count == 3 and inv.items[3] == nil)
assert(inv:move(1, 2)); assert(inv.items[2].name == 'water' and inv.items[1].name == 'WEAPON_KNIFE')   -- swap
assert(inv:remove('water', 2)); assert(inv.items[2].count == 1)
assert(inv:set('water', 0)); assert(inv.items[2] == nil)
inv:clear('weapon_knife'); assert(inv.items[1] and inv.items[1].name == 'WEAPON_KNIFE')
local search = require 'shared.search'
assert(search.count(inv.items, 'weapon_knife') == 1 and search.count(inv.items, 'WEAPON_KNIFE') == 1)
assert(inv:remove('WEAPON_KNIFE', 1)); assert(inv.items[1] == nil)
local old = Inventory.new('CID3', 5, 99999, { { slot = 1, name = 'weapon_pistol', count = 1, metadata = { serial = 'X' } } })
assert(old.items[1].name == 'WEAPON_PISTOL')        -- saved lowercase names load under the canonical name
print('all inventory tests passed')
