dofile('harness.lua')
local Inventory = require 'server.inventory'
local weapons = require 'server.weapons'
local inv = Inventory.new('CID', 10, 99999, {})
assert(inv:add('weapon_pistol', 1)); assert(inv:add('ammo-9', 20)); assert(inv:add('weapon_knife', 1))
local serial = inv.items[1].metadata.serial
assert(select(2, weapons.toggle(inv, 2)) == 'not_weapon')
local ok, data = weapons.toggle(inv, 1); assert(ok and data.serial == serial and data.ammo == 0 and data.ammoname == 'ammo-9')
assert(weapons.reload(inv, 'other', 0, 12) == false)
assert(select(2, weapons.reload(inv, serial, 0)) == 'not_weapon')     -- no clip size known
local ok2, ammo = weapons.reload(inv, serial, 0, 12); assert(ok2 and ammo == 12 and inv.items[2].count == 8)
assert(weapons.setAmmo(inv, serial, 5)); assert(not weapons.setAmmo(inv, serial, 9))
local ok3, ammo3 = weapons.reload(inv, serial, 4, 12); assert(ok3 and ammo3 == 12 and inv.items[2] == nil)
assert(select(2, weapons.reload(inv, serial, 12, 12)) == 'clip_full')
assert(inv:add('ammo-9', 500)); assert(select(2, weapons.reload(inv, serial, 12, 9999)) == 12 + 88)  -- capped by MaxClip
assert(inv:remove('WEAPON_PISTOL', 1)); assert(weapons.check(inv) and inv.equipped == nil)
print('all weapon tests passed')
