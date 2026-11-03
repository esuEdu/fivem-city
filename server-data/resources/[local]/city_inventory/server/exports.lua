-- Same names and arguments as ox_inventory's server exports, so qbx_core (and scripts written for ox_inventory) work unchanged.
-- `inv` is a player's server id, a stash id, or the table GetInventory returned.

local Items = require 'shared.items'
local search = require 'shared.search'
local inventories = require 'server.inventories'
local stashes = require 'server.stashes'
local shops = require 'server.shops'
local hooks = require 'server.hooks'

local resolve = inventories.resolve

---ox_inventory accepts a string as shorthand for { type = string }
---@param metadata unknown
---@return table?
local function toMetadata(metadata)
    if type(metadata) == 'string' then
        return { type = metadata }
    end

    return type(metadata) == 'table' and metadata or nil
end

---@param inventory Inventory
---@param success boolean
---@param reason? string
---@return boolean, string?
local function finish(inventory, success, reason)
    if success then
        inventories.sync(inventory)
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
    local inventory = resolve(inv)
    if not inventory then return end

    local items = {}

    for slot in pairs(inventory.items) do
        items[slot] = inventory:slotData(slot)
    end

    return {
        id = inventory.id,
        type = inventory.type,
        owner = inventory.owner,
        slots = inventory.slotCount,
        maxWeight = inventory.maxWeight,
        weight = inventory.weight,
        items = items,
    }
end)

exports('AddItem', function(inv, name, count, metadata, slot, cb)
    local inventory = resolve(inv)
    local success, reason = false, 'invalid_inventory'

    if inventory then
        success, reason = finish(inventory, inventory:add(name, count, toMetadata(metadata), slot and math.tointeger(slot)))
    end

    if cb then
        cb(success, reason)
    end

    return success, reason
end)

exports('RemoveItem', function(inv, name, count, metadata, slot)
    local inventory = resolve(inv)
    if not inventory then return false, 'invalid_inventory' end

    return finish(inventory, inventory:remove(name, count, toMetadata(metadata), slot and math.tointeger(slot)))
end)

exports('SetItem', function(inv, name, count, metadata)
    local inventory = resolve(inv)
    if not inventory then return false, 'invalid_inventory' end

    return finish(inventory, inventory:set(name, count, toMetadata(metadata)))
end)

exports('ClearInventory', function(inv, keep)
    local inventory = resolve(inv)
    if not inventory then return end

    inventory:clear(keep)
    inventories.sync(inventory)
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

exports('RegisterStash', stashes.register)

exports('RegisterShop', shops.register)

-- For scripts that already checked the player may open it (qbx_properties), so groups, distance and hooks are skipped
exports('forceOpenInventory', function(playerId, invType, data)
    local src = math.tointeger(tonumber(playerId))
    if not src or not GetPlayerName(src) then return end

    if invType ~= 'stash' then
        return lib.print.warn(('%s asked to open a %s inventory, which city_inventory does not have yet'):format(GetInvokingResource(), invType))
    end

    local id = type(data) == 'table' and data.id or data
    shops.close(src)
    local success, reason = stashes.open(src, id, true)

    if not success then
        lib.print.warn(('Could not open stash %s for player %s (%s)'):format(id, src, reason))
    end
end)

---@param invoker? string the script that called the ox_inventory stand-in, which forwards it
---@return string
local function caller(invoker)
    local resource = GetInvokingResource()
    return resource == 'ox_inventory' and type(invoker) == 'string' and invoker or resource
end

exports('registerHook', function(event, fn, options, invoker)
    return hooks.register(event, fn, options, caller(invoker))
end)

exports('removeHooks', function(id, invoker)
    hooks.remove(caller(invoker), id)
end)
