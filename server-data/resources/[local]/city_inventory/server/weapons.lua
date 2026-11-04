-- Weapon state kept on the inventory. A weapon is tracked by its serial, so moving it between slots keeps it equipped.

local Items = require 'shared.items'
local search = require 'shared.search'
local Inventory = require 'server.inventory'

local weapons = {}

---@param inventory Inventory
---@param serial unknown
---@return integer? slot
local function findSerial(inventory, serial)
    if type(serial) ~= 'string' then return end

    for slot, item in pairs(inventory.items) do
        if item.metadata.serial == serial and Items[item.name].weapon then
            return slot
        end
    end
end

---@param inventory Inventory
---@param slot integer
---@param ammo integer
local function setSlotAmmo(inventory, slot, ammo)
    local item = inventory.items[slot]
    local metadata = lib.table.deepclone(item.metadata)
    metadata.ammo = ammo

    inventory:setSlot(slot, { name = item.name, count = item.count, metadata = metadata })
end

---@param inventory Inventory
---@param slot unknown
---@return InventoryItem? item the weapon in `slot`
function weapons.at(inventory, slot)
    local item = inventory:isSlot(slot) and inventory.items[slot]

    return item and Items[item.name].weapon and item or nil
end

---Equips the weapon in `slot`, or unequips it when it is already equipped.
---@param inventory Inventory
---@param slot integer
---@return boolean success
---@return table | string | nil result weapon data when equipped, nil when unequipped, or the failure reason
function weapons.toggle(inventory, slot)
    local item = weapons.at(inventory, slot)
    if not item then return false, 'not_weapon' end

    if inventory.equipped == item.metadata.serial then
        inventory.equipped = nil
        return true, nil
    end

    inventory.equipped = item.metadata.serial

    return true, {
        name = item.name,
        serial = item.metadata.serial,
        ammo = item.metadata.ammo,
        ammoname = Items[item.name].ammoname,
        components = item.metadata.components,
    }
end

---@param inventory Inventory
function weapons.unequip(inventory)
    inventory.equipped = nil
end

---Call after the inventory changed.
---@param inventory Inventory
---@return boolean disarm true when the equipped weapon left the inventory
function weapons.check(inventory)
    if inventory.equipped and not findSerial(inventory, inventory.equipped) then
        inventory.equipped = nil
        return true
    end

    return false
end

---Records ammo the client used. It can only go down, so a modified client can't create ammo this way.
---@param inventory Inventory
---@param serial unknown
---@param ammo unknown
---@return boolean changed
function weapons.setAmmo(inventory, serial, ammo)
    local slot = findSerial(inventory, serial)
    local stored = slot and inventory.items[slot].metadata.ammo
    ammo = type(ammo) == 'number' and math.tointeger(ammo)

    if not stored or not ammo or ammo < 0 or ammo >= stored then return false end

    setSlotAmmo(inventory, slot, ammo)

    return true
end

---@param definition ItemDefinition
---@param clipHint unknown magazine size the client's game reports
---@return integer?
local function clipSize(definition, clipHint)
    if definition.clip then return definition.clip end

    -- Loading more rounds than a magazine holds only moves ammo the player already owns, so the hint is safe to use capped
    clipHint = type(clipHint) == 'number' and math.tointeger(clipHint)
    if not clipHint or clipHint < 1 then return end

    return math.min(clipHint, Config.MaxClip)
end

---Fills the equipped weapon's clip from its ammo items.
---@param inventory Inventory
---@param serial unknown
---@param ammo unknown rounds left in the weapon, as the client sees it
---@param clipHint unknown magazine size, used when data/weapons.lua sets no clip
---@return boolean success
---@return integer | string result new ammo count, or the failure reason
function weapons.reload(inventory, serial, ammo, clipHint)
    if serial ~= inventory.equipped then return false, 'not_weapon' end

    weapons.setAmmo(inventory, serial, ammo)

    local slot = findSerial(inventory, serial)
    local item = slot and inventory.items[slot]
    local definition = item and Items[item.name]
    local clip = definition and clipSize(definition, clipHint)
    if not definition or not definition.ammoname or not clip then return false, 'not_weapon' end

    local current = item.metadata.ammo or 0
    local loaded = math.min(clip - current, search.count(inventory.items, definition.ammoname))
    if loaded <= 0 then return false, current >= clip and 'clip_full' or 'no_ammo' end

    inventory:remove(definition.ammoname, loaded)
    setSlotAmmo(inventory, slot, current + loaded)

    return true, current + loaded
end

---Loads the weapon in `weaponSlot` with ammo from `ammoSlot`, e.g. when the player drags the ammo onto it. It fills the
---magazine and the spare rounds the gun carries (Config.ReserveMagazines more magazines).
---@param inventory Inventory
---@param weaponSlot integer
---@param ammoSlot integer
---@param count unknown most rounds to load, defaults to all in the slot
---@param clipHint unknown magazine size, used when data/weapons.lua sets no clip
---@return boolean success
---@return table | string result { serial, ammo } or the failure reason
function weapons.load(inventory, weaponSlot, ammoSlot, count, clipHint)
    local weapon = weapons.at(inventory, weaponSlot)
    local definition = weapon and Items[weapon.name]
    if not definition or not definition.ammoname then return false, 'not_weapon' end

    local ammo = inventory:isSlot(ammoSlot) and inventory.items[ammoSlot]
    if not ammo or ammo.name ~= Items[definition.ammoname].name then return false, 'wrong_ammo' end

    local clip = clipSize(definition, clipHint)
    if not clip then return false, 'not_weapon' end

    local capacity = math.min(clip * (1 + Config.ReserveMagazines), Config.MaxGunAmmo)
    local current = weapon.metadata.ammo or 0
    local loaded = math.min(Inventory.toCount(count) or ammo.count, ammo.count, capacity - current)
    if loaded <= 0 then return false, 'clip_full' end

    inventory:remove(ammo.name, loaded, nil, ammoSlot)
    setSlotAmmo(inventory, weaponSlot, current + loaded)

    return true, { serial = weapon.metadata.serial, ammo = current + loaded }
end

---Takes the rounds out of the weapon in `slot` and puts them back as ammo items.
---@param inventory Inventory
---@param slot integer
---@return boolean success
---@return table | string result { serial, ammo = 0 } or the failure reason
function weapons.unload(inventory, slot)
    local weapon = weapons.at(inventory, slot)
    local definition = weapon and Items[weapon.name]
    local rounds = weapon and weapon.metadata.ammo
    if not definition or not definition.ammoname or not rounds or rounds < 1 then return false, 'no_ammo' end

    -- Empty the gun first: the rounds then weigh nothing extra when they come back as items
    setSlotAmmo(inventory, slot, 0)

    local success, reason = inventory:add(definition.ammoname, rounds)

    if not success then
        setSlotAmmo(inventory, slot, rounds)
        return false, reason
    end

    return true, { serial = weapon.metadata.serial, ammo = 0 }
end

return weapons
