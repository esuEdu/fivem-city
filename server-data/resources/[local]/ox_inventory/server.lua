local inventory = exports.city_inventory

-- ox_inventory server exports that city_inventory has, under the same names and arguments
local FORWARDED = {
    'Items', 'GetInventory', 'GetInventoryItems', 'AddItem', 'RemoveItem', 'SetItem', 'ClearInventory', 'CanCarryItem',
    'GetItem', 'GetItemCount', 'Search', 'GetSlot', 'GetSlotWithItem', 'GetSlotsWithItem', 'GetSlotIdWithItem',
    'SetMetadata', 'GetCurrentWeapon', 'ConfiscateInventory', 'ReturnInventory',
}

-- ox_inventory server exports for features city_inventory doesn't have yet
local UNSUPPORTED = {
    'RegisterStash', 'RegisterShop', 'CustomDrop', 'CreateDropFromPlayer', 'forceOpenInventory', 'registerHook',
}

for _, name in ipairs(FORWARDED) do
    exports(name, function(...)
        return inventory[name](inventory, ...)
    end)
end

for _, name in ipairs(UNSUPPORTED) do
    exports(name, function()
        lib.print.warn(('%s called %s, which city_inventory does not have yet (stashes, shops and drops)'):format(GetInvokingResource() or 'a script', name))
    end)
end
