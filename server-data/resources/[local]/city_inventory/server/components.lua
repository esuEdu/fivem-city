-- Weapon attachments, kept by name in the weapon's metadata.components (as ox_inventory did).
-- Whether a part fits a gun is a client-only check (DoesWeaponTakeWeaponComponent). Attaching only moves an item the
-- player owns into the gun and removing gives it back, so trusting that check can't create anything.

local Items = require 'shared.items'
local weapons = require 'server.weapons'

local components = {}

---@param inventory Inventory
---@param slot integer
---@param weapon InventoryItem
---@param list string[]
local function setComponents(inventory, slot, weapon, list)
    local metadata = lib.table.deepclone(weapon.metadata)
    metadata.components = #list > 0 and list or nil

    inventory:setSlot(slot, { name = weapon.name, count = weapon.count, metadata = metadata })
end

---@param inventory Inventory
---@param weaponSlot integer
---@param componentSlot integer
---@return boolean success
---@return string? reason
function components.attach(inventory, weaponSlot, componentSlot)
    local weapon = weapons.at(inventory, weaponSlot)
    if not weapon then return false, 'not_weapon' end

    local part = inventory:isSlot(componentSlot) and inventory.items[componentSlot]
    local definition = part and Items[part.name]
    if not definition or not definition.component then return false, 'not_component' end

    local list = lib.table.deepclone(weapon.metadata.components or {})

    for _, name in ipairs(list) do
        if Items[name] and Items[name].componentType == definition.componentType then
            return false, 'component_taken'
        end
    end

    list[#list + 1] = definition.name

    inventory:remove(definition.name, 1, nil, componentSlot)
    setComponents(inventory, weaponSlot, weapon, list)

    return true
end

---@param inventory Inventory
---@param weaponSlot integer
---@param name unknown the attachment to take off
---@return boolean success
---@return string? reason
function components.detach(inventory, weaponSlot, name)
    local weapon = weapons.at(inventory, weaponSlot)
    if not weapon then return false, 'not_weapon' end

    local list = lib.table.deepclone(weapon.metadata.components or {})
    local index

    for i, attached in ipairs(list) do
        if attached == name then index = i break end
    end

    if not index then return false, 'not_component' end

    table.remove(list, index)
    setComponents(inventory, weaponSlot, weapon, list)

    -- The part was counted in the gun's weight, so taking it off only fails when there's no free slot
    local success, reason = inventory:add(name, 1)

    if not success then
        setComponents(inventory, weaponSlot, weapon, weapon.metadata.components)
        return false, reason
    end

    return true
end

return components
