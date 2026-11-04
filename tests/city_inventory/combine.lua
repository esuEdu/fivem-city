dofile('harness.lua')
Config.Recipes = {
    { ingredients = { { 'rolling_paper', 1 }, { 'weed_skunk', 1 } }, result = { 'joint', 1 }, duration = 3000 },
    { ingredients = { { 'metalscrap', 5 }, { 'rubber', 2 } }, result = { 'repairkit', 1 } },
    { ingredients = { { 'water', 1 }, { 'nope_item', 1 } }, result = { 'joint', 1 } },
}
local Items = require 'shared.items'
local weightOf = require 'shared.weight'
local Inventory = require 'server.inventory'
local weapons = require 'server.weapons'
local components = require 'server.components'
local crafting = require 'server.crafting'

local function total(inv) local w = 0 for _, it in pairs(inv.items) do w = w + weightOf(it) end return w end
local function check(inv) assert(inv.weight == total(inv), ('weight %d ~= %d'):format(inv.weight, total(inv))) end

assert(Items.at_flashlight.component and Items.at_flashlight.componentType == 'flashlight' and #Items.at_flashlight.hashes > 0)

-- weight follows every change
local inv = Inventory.new('C', 10, 100000)
assert(inv:add('WEAPON_PISTOL', 1)); assert(inv:add('ammo-9', 50)); assert(inv:add('at_flashlight', 1)); assert(inv:add('at_suppressor_light', 1))
check(inv)
local pistol, ammo = 1, 2
local base = inv.weight

-- load: wrong ammo / clip cap / partial
assert(inv:add('ammo-rifle', 5)); local rifleAmmo = 5
assert(select(2, weapons.load(inv, pistol, rifleAmmo, nil, 12)) == 'wrong_ammo')
assert(select(2, weapons.load(inv, ammo, pistol, nil, 12)) == 'not_weapon')
local ok, res = weapons.load(inv, pistol, ammo, 5, 12); assert(ok and res.ammo == 5 and inv.items[ammo].count == 45); check(inv)
-- a 12-round magazine plus 8 spare magazines: 108 rounds fit, so all 45 left go in
ok, res = weapons.load(inv, pistol, ammo, nil, 12); assert(ok and res.ammo == 50 and inv.items[ammo] == nil); check(inv)
assert(inv:add('ammo-9', 100)); ammo = 2
assert(inv.items[ammo].name == 'ammo-9')
ok, res = weapons.load(inv, pistol, ammo, nil, 12); assert(ok and res.ammo == 108 and inv.items[ammo].count == 42); check(inv)
assert(select(2, weapons.load(inv, pistol, ammo, nil, 12)) == 'clip_full')
assert(select(2, weapons.load(inv, pistol, ammo, nil, nil)) == 'not_weapon')   -- no clip known
-- the game's limit caps the total (30 x 9 = 270 > 250)
local big = Inventory.new('BIG', 5, 1000000); assert(big:add('WEAPON_PISTOL', 1)); assert(big:add('ammo-9', 300))
ok, res = weapons.load(big, 1, 2, nil, 30); assert(ok and res.ammo == 250)
assert(inv:remove('ammo-9', 42))
ok, res = weapons.unload(inv, pistol); assert(ok and res.ammo == 0); check(inv)
assert(inv:remove('ammo-9', 108))
ok, res = weapons.load(inv, pistol, rifleAmmo, nil, 12)
assert(inv:add('ammo-9', 50)); ammo = 2
ok, res = weapons.load(inv, pistol, ammo, nil, 12); assert(ok and res.ammo == 50 and inv.items[ammo] == nil)
check(inv)

-- unload
ok, res = weapons.unload(inv, pistol); assert(ok and res.ammo == 0 and inv.items[pistol].metadata.ammo == 0); check(inv)
assert(require('shared.search').count(inv.items, 'ammo-9') == 50)
assert(select(2, weapons.unload(inv, pistol)) == 'no_ammo')

-- unload refused when no slot is free
local full = Inventory.new('F', 1, 100000)
assert(full:add('WEAPON_PISTOL', 1, { ammo = 10 }))
ok, res = weapons.unload(full, 1); assert(not ok and res == 'inventory_full' and full.items[1].metadata.ammo == 10); check(full)

-- attach / detach
local light, supp = 3, 4
assert(inv.items[light].name == 'at_flashlight')
assert(components.attach(inv, pistol, light)); assert(inv.items[light] == nil and inv.items[pistol].metadata.components[1] == 'at_flashlight'); check(inv)
assert(inv:add('at_flashlight', 1)); local light2 = 3
assert(select(2, components.attach(inv, pistol, light2)) == 'component_taken')
assert(components.attach(inv, pistol, supp)); assert(#inv.items[pistol].metadata.components == 2); check(inv)
assert(select(2, components.attach(inv, ammo, supp)) == 'not_weapon')
assert(select(2, components.detach(inv, pistol, 'at_scope_large')) == 'not_component')
assert(components.detach(inv, pistol, 'at_suppressor_light')); assert(#inv.items[pistol].metadata.components == 1); check(inv)
-- detach refused when full
local f2 = Inventory.new('F2', 1, 100000)
assert(f2:add('WEAPON_PISTOL', 1, { components = { 'at_flashlight' } })); check(f2)
assert(f2.weight == Items.WEAPON_PISTOL.weight + Items.at_flashlight.weight)
ok, res = components.detach(f2, 1, 'at_flashlight'); assert(not ok and res == 'inventory_full' and f2.items[1].metadata.components[1] == 'at_flashlight'); check(f2)

-- crafting
assert(crafting.recipeFor('weed_skunk', 'rolling_paper') and crafting.recipeFor('RUBBER', 'metalscrap'))
assert(crafting.recipeFor('water', 'nope_item') == nil)
local c = Inventory.new('K', 4, 100000)
assert(c:add('metalscrap', 4)); assert(c:add('rubber', 2))
local r = crafting.recipeFor('metalscrap', 'rubber')
assert(select(2, crafting.craft(c, r)) == 'missing_ingredients')
assert(c:add('metalscrap', 1)); assert(crafting.craft(c, r)); check(c)
assert(require('shared.search').count(c.items, 'repairkit') == 1 and require('shared.search').count(c.items, 'metalscrap') == 0)
-- full: result doesn't fit -> nothing taken
local k = Inventory.new('K2', 2, 100000)
assert(k:add('rolling_paper', 2)); assert(k:add('weed_skunk', 2))
local before = { k.items[1], k.items[2] }; local w = k.weight
ok, res = crafting.craft(k, crafting.recipeFor('rolling_paper', 'weed_skunk'))
assert(not ok and res == 'inventory_full' and k.items[1] == before[1] and k.items[2] == before[2] and k.weight == w); check(k)

-- move/clear keep weight
assert(inv:move(pistol, 9)); check(inv); inv:clear(); assert(inv.weight == 0)
print('all combine tests passed')
