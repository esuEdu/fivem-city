-- Effects of the starter consumables. Other resources make their own items usable with exports.qbx_core:CreateUseableItem.

local MAX_STATUS = 100

for name, effects in pairs(Config.Consumables) do
    exports.qbx_core:CreateUseableItem(name, function(source)
        for status, amount in pairs(effects) do
            if status == 'health' then
                -- Health belongs to the ped, which the client owns
                TriggerClientEvent('city_inventory:client:heal', source, amount)
            else
                local current = Player(source).state[status] or 0
                exports.qbx_core:SetMetadata(source, status, math.min(MAX_STATUS, current + amount))
            end
        end
    end)
end
