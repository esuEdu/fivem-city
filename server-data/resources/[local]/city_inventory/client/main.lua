local Items = require 'shared.items'
local search = require 'shared.search'

-- Read-only copy of the player's inventory; the server sends every change
---@type table<integer, InventoryItem>
local items = {}
local weight = 0

RegisterNetEvent('city_inventory:client:setInventory', function(newItems, newWeight)
    items = newItems
    weight = newWeight
end)

RegisterNetEvent('city_inventory:client:updateSlots', function(changes, newWeight)
    for slot, item in pairs(changes) do
        items[slot] = item or nil
    end

    weight = newWeight
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    items = {}
    weight = 0
end)

-- Same names and arguments as ox_inventory's client exports

exports('Items', function(name)
    if name then
        return Items[name]
    end

    return Items
end)

exports('GetItemCount', function(name, metadata, strict)
    return search.count(items, name, metadata, strict)
end)

exports('Search', function(kind, names, metadata)
    if kind ~= 'count' and kind ~= 'slots' then return end

    return search.run(items, kind, names, metadata, function(slot)
        local item = items[slot]

        return { slot = slot, name = item.name, count = item.count, metadata = item.metadata, label = Items[item.name].label }
    end)
end)

exports('GetPlayerWeight', function()
    return weight
end)
