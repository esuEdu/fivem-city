local inventory = exports.city_inventory

-- ox_inventory client exports that city_inventory has, under the same names and arguments
local FORWARDED = {
    'Items', 'GetItemCount', 'Search', 'GetPlayerWeight', 'GetPlayerItems', 'getCurrentWeapon',
    'openInventory', 'closeInventory', 'openNearbyInventory', 'displayMetadata',
}

for _, name in ipairs(FORWARDED) do
    exports(name, function(...)
        return inventory[name](inventory, ...)
    end)
end
