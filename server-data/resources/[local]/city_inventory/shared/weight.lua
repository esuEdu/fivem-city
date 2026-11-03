-- What an item in a slot weighs. Like ox_inventory, a gun also carries the weight of its attachments and loaded rounds.

local Items = require 'shared.items'

---@param item InventoryItem
---@return integer grams
return function(item)
    local definition = Items[item.name]
    local each = definition.weight
    local metadata = item.metadata

    if definition.weapon and metadata then
        for _, name in ipairs(type(metadata.components) == 'table' and metadata.components or {}) do
            local component = Items[name]
            if component then each = each + component.weight end
        end

        local ammo = definition.ammoname and Items[definition.ammoname]

        if ammo and type(metadata.ammo) == 'number' then
            each = each + ammo.weight * metadata.ammo
        end
    end

    return each * item.count
end
