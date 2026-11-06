-- Medical items anyone can use on themselves. The client plays the animation and applies the effect; the item is only
-- taken once the progress bar finished.
local ITEMS = { 'bandage', 'painkillers', 'ifaks' }

for _, name in ipairs(ITEMS) do
    exports.qbx_core:CreateUseableItem(name, function(source, item)
        local src = source

        if Player(src).state.isDead then return false end

        local used = lib.callback.await('city_hospital:useItem', src, name)

        if used then exports.city_inventory:RemoveItem(src, name, 1, nil, item.slot) end

        -- false: the inventory doesn't consume it; we already did (or it wasn't used)
        return false
    end)
end
