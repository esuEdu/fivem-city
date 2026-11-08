local gear = require 'shared.gear'
local profiles = require 'server.profiles'
local tournaments = require 'server.tournaments'
local util = require 'server.util'

MySQL.ready(function()
    profiles.init()
    tournaments.init()
end)

-- Using a rod starts or stops fishing on the client; everything after that is checked in sessions.lua
for name in pairs(gear.rods) do
    exports.qbx_core:CreateUseableItem(name, function(source, item)
        local src = source
        local _, citizenid = util.player(src)
        if not citizenid or type(item) ~= 'table' then return false end

        local profile = profiles.get(citizenid)
        TriggerClientEvent('city_fishing:client:useRod', src, item.slot, profile.level)
    end)
end

-- Using a bait puts it on every rod that takes bait (one is taken from the inventory per cast)
for name in pairs(gear.baits) do
    exports.qbx_core:CreateUseableItem(name, function(source)
        local src = source
        if not util.player(src) then return false end

        local fitted = 0
        for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
            local rod = gear.rods[item.name]

            if rod and rod.bait then
                local metadata = item.metadata or {}
                metadata.bait = name
                exports.city_inventory:SetMetadata(src, item.slot, metadata)
                fitted = fitted + 1
            end
        end

        util.notify(src, fitted > 0 and 'bait_fitted' or 'bait_no_rod', fitted > 0 and 'success' or 'error')

        return false
    end)
end

-- Using a tackle fits it on the first rod with a free slot
for name in pairs(gear.tackle) do
    exports.qbx_core:CreateUseableItem(name, function(source, used)
        local src = source
        if not util.player(src) then return false end

        local slots = {}
        for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do slots[#slots + 1] = item end
        table.sort(slots, function(a, b) return a.slot < b.slot end)

        for _, item in ipairs(slots) do
            local rod = gear.rods[item.name]
            local metadata = item.metadata or {}
            local tackle = type(metadata.tackle) == 'table' and metadata.tackle or {}

            if rod and #tackle < rod.slots then
                if not exports.city_inventory:RemoveItem(src, name, 1, nil, used.slot) then return false end

                tackle[#tackle + 1] = { name = name, uses = gear.tackleUses }
                metadata.tackle = tackle
                exports.city_inventory:SetMetadata(src, item.slot, metadata)
                util.notify(src, 'tackle_fitted', 'success')

                return false
            end
        end

        util.notify(src, 'tackle_no_slot', 'error')

        return false
    end)
end

exports.qbx_core:CreateUseableItem(gear.pot.item, function(source)
    local src = source
    if not util.player(src) then return false end

    TriggerClientEvent('city_fishing:client:placePot', src)

    return false
end)

exports.qbx_core:CreateUseableItem(gear.licence.item, function(source, item)
    local src = source
    local metadata = type(item) == 'table' and item.metadata or {}
    if type(metadata.expires) ~= 'number' then return false end

    local key = metadata.expires > os.time() and 'licence_shown' or 'licence_shown_expired'
    util.notify(src, key, 'inform', metadata.holder or '?', os.date('%Y-%m-%d %H:%M', metadata.expires))

    return false
end)
