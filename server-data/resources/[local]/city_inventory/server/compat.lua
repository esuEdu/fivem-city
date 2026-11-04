-- More of ox_inventory's server exports, for the Qbox scripts that use them (ox_fuel, qbx_police, mm_radio, xt-prison, ...).

local Items = require 'shared.items'
local search = require 'shared.search'
local inventories = require 'server.inventories'
local storage = require 'server.storage'

local resolve = inventories.resolve

---@param inventory Inventory
---@return string
local function confiscatedKey(inventory)
    return ('confiscated:%s'):format(inventory.owner)
end

exports('SetMetadata', function(inv, slot, metadata)
    local inventory = resolve(inv)
    slot = math.tointeger(slot)
    local item = inventory and inventory:isSlot(slot) and inventory.items[slot]
    if not item or type(metadata) ~= 'table' then return end

    -- A weapon keeps its serial, so it stays the same weapon (and stays equipped)
    if Items[item.name].weapon then
        metadata.serial = item.metadata.serial
    end

    inventory:setSlot(slot, { name = item.name, count = item.count, metadata = metadata })
    inventories.sync(inventory)
end)

exports('GetCurrentWeapon', function(inv)
    local inventory = resolve(inv)
    if not inventory or not inventory.equipped then return end

    for slot, item in pairs(inventory.items) do
        if item.metadata.serial == inventory.equipped and Items[item.name].weapon then
            return inventory:slotData(slot)
        end
    end
end)

exports('GetSlotIdWithItem', function(inv, name, metadata, strict)
    local inventory = resolve(inv)

    return inventory and search.slots(inventory.items, name, metadata, strict)[1]
end)

exports('GetItem', function(inv, name, metadata, returnsCount)
    local inventory = resolve(inv)
    local definition = Items[name]
    if not inventory or not definition then return end

    local count = search.count(inventory.items, name, metadata)
    if returnsCount then return count end

    local item = lib.table.deepclone(definition)
    item.count = count

    return item
end)

exports('GetInventoryItems', function(inv)
    local inventory = resolve(inv)
    if not inventory then return end

    local items = {}

    for slot in pairs(inventory.items) do
        items[slot] = inventory:slotData(slot)
    end

    return items
end)

-- Takes everything the player carries and keeps it until ReturnInventory (e.g. while in jail)
exports('ConfiscateInventory', function(inv)
    local inventory = resolve(inv)
    if not inventory or not next(inventory.items) then return end

    local entries = {}

    for slot, item in pairs(inventory.items) do
        entries[#entries + 1] = { slot = slot, name = item.name, count = item.count, metadata = item.metadata }
    end

    storage.save({ { owner = confiscatedKey(inventory), entries = entries } })

    inventory:clear()
    inventories.sync(inventory)
end)

exports('ReturnInventory', function(inv)
    local inventory = resolve(inv)
    if not inventory then return end

    local key = confiscatedKey(inventory)
    local entries = storage.load(key)
    if not entries or #entries == 0 then return end

    for _, entry in ipairs(entries) do
        local success, reason = inventory:add(entry.name, entry.count, entry.metadata)

        if not success then
            lib.print.warn(('Could not return %sx %s to %s (%s)'):format(entry.count, entry.name, inventory.id, reason))
        end
    end

    storage.save({ { owner = key, entries = {} } })
    inventories.sync(inventory)
end)
