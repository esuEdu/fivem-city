-- The mining shop at Davis Quartz: licences, tools by level, safety gear, the home furnace, repairs and the skill
-- reset. Prices come from shared/gear.lua and server config, never from the client. Paid cash first, then bank.
local settings = require 'server.config'
local gear = require 'shared.gear'
local profiles = require 'server.profiles'
local util = require 'server.util'

local RANGE = 4.0
local MAX_COUNT = { pickaxe = 1, pan = 1, sluice = 1, ppe = 1, furnace = 1 }

---@param src integer
---@return boolean
local function atShop(src)
    return util.near(src, Config.Shop.coords, RANGE)
end

---@param name string
---@return table? catalogue entry
local function entryFor(name)
    for _, entry in ipairs(gear.catalogue()) do
        if entry.item == name then return entry end
    end
end

---Cost to repair every worn tool the player carries, and the slots to fix.
---@param src integer
---@return integer cost
---@return table[] slots
local function repairs(src)
    local cost, slots = 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local max = gear.durability(item.name)

        if max then
            local durability = tonumber(item.metadata and item.metadata.durability) or max

            if durability < max then
                cost = cost + math.ceil(gear.price(item.name) * gear.repairShare * (max - durability) / max)
                slots[#slots + 1] = item
            end
        end
    end

    return cost, slots
end

---@param src integer
---@param citizenid string
---@param licence table gear.licence or gear.explosives
---@param reason string
---@return boolean ok
---@return string|integer result
local function sellLicence(src, citizenid, licence, reason)
    local _, expires = util.licence(src, citizenid, licence.item)
    local metadata = { citizenid = citizenid, holder = util.name(src) }
    metadata.expires = math.max(os.time(), expires or 0) + licence.days * 86400
    metadata.description = locale('licence_description', metadata.holder, os.date('%Y-%m-%d %H:%M', metadata.expires))

    if not exports.city_inventory:CanCarryItem(src, licence.item, 1, metadata) then return false, 'inventory_full' end
    if not util.pay(src, licence.price, reason) then return false, 'no_money' end

    -- The old card of this character is replaced by the extended one
    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, licence.item) or {}) do
        if slot.metadata and slot.metadata.citizenid == citizenid then
            exports.city_inventory:RemoveItem(src, licence.item, 1, nil, slot.slot)
        end
    end

    exports.city_inventory:AddItem(src, licence.item, 1, metadata)

    return true, metadata.expires
end

lib.callback.register('city_mining:shopInfo', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player or not atShop(src) then return false end

    local profile = profiles.get(citizenid)
    local valid, expires = util.licence(src, citizenid, gear.licence.item)
    local explosivesValid, explosivesExpires = util.licence(src, citizenid, gear.explosives.item)

    return true, {
        level = profile.level,
        golden = profiles.skill(profile, 'golden_pan') > 0,
        licence = { valid = valid, expires = expires and os.date('%Y-%m-%d %H:%M', expires) or nil, price = gear.licence.price },
        explosives = {
            granted = util.explosivesGranted(player),
            valid = explosivesValid,
            expires = explosivesExpires and os.date('%Y-%m-%d %H:%M', explosivesExpires) or nil,
            price = gear.explosives.price,
            level = gear.explosives.level,
        },
        repair = (repairs(src)),
        respec = settings.respec.price,
    }
end)

lib.callback.register('city_mining:buy', function(source, name)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local entry = type(name) == 'string' and entryFor(name)
    if not entry then return false, 'invalid' end
    if not atShop(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    if profile.level < entry.level then return false, 'level_low' end
    if entry.kind == 'sluice' and profiles.skill(profile, gear.sluice.skill) <= 0 then return false, 'needs_golden_pan' end
    if util.count(src, name) >= MAX_COUNT[entry.kind] then return false, 'already_have' end

    local metadata
    local max = gear.durability(name)
    if max then metadata = { durability = max, description = locale('durability_text', max, max) } end

    if not exports.city_inventory:CanCarryItem(src, name, 1, metadata) then return false, 'inventory_full' end
    if not util.pay(src, entry.price, 'mining-shop') then return false, 'no_money' end

    exports.city_inventory:AddItem(src, name, 1, metadata)

    return true, entry.price
end)

lib.callback.register('city_mining:buyLicence', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    return sellLicence(src, citizenid, gear.licence, 'mining-licence')
end)

lib.callback.register('city_mining:buyExplosives', function(source)
    if not Config.Features.dynamite then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    if not util.explosivesGranted(player) then return false, 'explosives_not_granted' end
    if profiles.get(citizenid).level < gear.explosives.level then return false, 'level_low' end

    return sellLicence(src, citizenid, gear.explosives, 'mining-explosives-licence')
end)

lib.callback.register('city_mining:repair', function(source)
    local src = source
    if not util.player(src) then return false end
    if not atShop(src) then return false, 'too_far' end

    local cost, slots = repairs(src)
    if #slots == 0 then return false, 'nothing_to_repair' end
    if not util.pay(src, cost, 'mining-repair') then return false, 'no_money' end

    for _, item in ipairs(slots) do
        local max = gear.durability(item.name)
        local metadata = item.metadata or {}
        metadata.durability = max
        metadata.description = locale('durability_text', max, max)
        exports.city_inventory:SetMetadata(src, item.slot, metadata)
    end

    return true, cost
end)

lib.callback.register('city_mining:respec', function(source)
    if not Config.Features.skills then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    if next(profile.skills) == nil then return false, 'nothing_to_reset' end
    if not util.pay(src, settings.respec.price, 'mining-respec') then return false, 'no_money' end

    profile.skills = {}
    profiles.save(profile)

    return true
end)
