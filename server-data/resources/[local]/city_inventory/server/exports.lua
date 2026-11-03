-- Same names and arguments as ox_inventory's server exports, so qbx_core (and scripts written for ox_inventory) work unchanged.
-- `inv` is a player's server id, or the table GetInventory returned.

local Items = require 'shared.items'
local search = require 'shared.search'
local players = require 'server.players'

local resolve = players.resolve

---ox_inventory accepts a string as shorthand for { type = string }
---@param metadata unknown
---@return table?
local function toMetadata(metadata)
    if type(metadata) == 'string' then
        return { type = metadata }
    end

    return type(metadata) == 'table' and metadata or nil
end

---@param src integer
---@param success boolean
---@param reason? string
---@return boolean, string?
local function finish(src, success, reason)
    if success then
        players.sync(src)
    end

    return success, reason
end

exports('Items', function(name)
    if name then
        return Items[name]
    end

    return Items
end)

exports('GetInventory', function(inv)
    local inventory, src = resolve(inv)
    if not inventory then return end

    local items = {}

    for slot in pairs(inventory.items) do
        items[slot] = inventory:slotData(slot)
    end

    return {
        id = src,
        type = 'player',
        owner = inventory.owner,
        slots = inventory.slotCount,
        maxWeight = inventory.maxWeight,
        weight = inventory.weight,
        items = items,
    }
end)

exports('AddItem', function(inv, name, count, metadata, slot, cb)
    local inventory, src = resolve(inv)
    local success, reason = false, 'invalid_inventory'

    if inventory then
        success, reason = finish(src, inventory:add(name, count, toMetadata(metadata), slot and math.tointeger(slot)))
    end

    if cb then
        cb(success, reason)
    end

    return success, reason
end)

exports('RemoveItem', function(inv, name, count, metadata, slot)
    local inventory, src = resolve(inv)
    if not inventory then return false, 'invalid_inventory' end

    return finish(src, inventory:remove(name, count, toMetadata(metadata), slot and math.tointeger(slot)))
end)

exports('SetItem', function(inv, name, count, metadata)
    local inventory, src = resolve(inv)
    if not inventory then return false, 'invalid_inventory' end

    return finish(src, inventory:set(name, count, toMetadata(metadata)))
end)

exports('ClearInventory', function(inv, keep)
    local inventory, src = resolve(inv)
    if not inventory then return end

    inventory:clear(keep)
    players.sync(src)
end)

exports('CanCarryItem', function(inv, name, count, metadata)
    local inventory = resolve(inv)

    return inventory and inventory:canFit(name, count, toMetadata(metadata)) or false
end)

exports('GetItemCount', function(inv, name, metadata, strict)
    local inventory = resolve(inv)

    return inventory and search.count(inventory.items, name, toMetadata(metadata), strict) or 0
end)

exports('Search', function(inv, kind, names, metadata)
    local inventory = resolve(inv)
    if not inventory or (kind ~= 'count' and kind ~= 'slots') then return end

    return search.run(inventory.items, kind, names, toMetadata(metadata), function(slot)
        return inventory:slotData(slot)
    end)
end)

exports('GetSlot', function(inv, slot)
    local inventory = resolve(inv)

    return inventory and inventory:slotData(math.tointeger(slot))
end)

exports('GetSlotWithItem', function(inv, name, metadata, strict)
    local inventory = resolve(inv)
    if not inventory then return end

    local slot = search.slots(inventory.items, name, toMetadata(metadata), strict)[1]

    return slot and inventory:slotData(slot)
end)

exports('GetSlotsWithItem', function(inv, name, metadata, strict)
    local inventory = resolve(inv)
    if not inventory then return end

    local result = {}

    for _, slot in ipairs(search.slots(inventory.items, name, toMetadata(metadata), strict)) do
        result[#result + 1] = inventory:slotData(slot)
    end

    return result
end)
