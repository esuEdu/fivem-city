local inventory = exports.city_inventory

-- ox_inventory server exports that city_inventory has, under the same names and arguments
local FORWARDED = {
    'Items', 'GetInventory', 'GetInventoryItems', 'AddItem', 'RemoveItem', 'SetItem', 'ClearInventory', 'CanCarryItem',
    'GetItem', 'GetItemCount', 'Search', 'GetSlot', 'GetSlotWithItem', 'GetSlotsWithItem', 'GetSlotIdWithItem',
    'SetMetadata', 'GetCurrentWeapon', 'ConfiscateInventory', 'ReturnInventory', 'RegisterStash', 'forceOpenInventory',
}

-- ox_inventory server exports for features city_inventory doesn't have yet
local UNSUPPORTED = {
    'RegisterShop', 'CustomDrop', 'CreateDropFromPlayer',
}

for _, name in ipairs(FORWARDED) do
    exports(name, function(...)
        return inventory[name](inventory, ...)
    end)
end

-- Hooks belong to the script that registered them (removed when it stops), so pass on who called
exports('registerHook', function(event, fn, options)
    return inventory:registerHook(event, fn, options, GetInvokingResource())
end)

exports('removeHooks', function(id)
    return inventory:removeHooks(id, GetInvokingResource())
end)

for _, name in ipairs(UNSUPPORTED) do
    exports(name, function()
        lib.print.warn(('%s called %s, which city_inventory does not have yet (shops and drops)'):format(GetInvokingResource() or 'a script', name))
    end)
end
