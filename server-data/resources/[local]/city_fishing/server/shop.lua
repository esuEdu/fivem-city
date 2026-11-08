-- The fishing shop: licence, gear by level (Merchant discount), rod repair and the skill reset. Prices come from
-- shared/gear.lua and server config, never from the client. Paid cash first, then bank.
local settings = require 'server.config'
local gear = require 'shared.gear'
local levels = require 'shared.levels'
local profiles = require 'server.profiles'
local util = require 'server.util'

local SHOP_RANGE = 4.0
local MAX_COUNT = { rod = 1, bait = 50, tackle = 5, pot = 5 }

---@param src integer
---@return boolean
local function atShop(src)
    for _, shop in ipairs(Config.Shops) do
        if util.near(src, shop.coords, SHOP_RANGE) then return true end
    end

    return false
end

---@param price integer
---@param skills table
---@return integer
local function discounted(price, skills)
    return math.floor(price * (1 - levels.value(skills, 'discount')) + 0.5)
end

---@param name string
---@return table? entry from gear.catalogue()
local function catalogueEntry(name)
    for _, entry in ipairs(gear.catalogue()) do
        if entry.item == name then return entry end
    end
end

lib.callback.register('city_fishing:shopInfo', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player or not atShop(src) then return false end

    local profile = profiles.get(citizenid)
    local valid, expires = util.licence(src, citizenid)

    local repair = 0
    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local rod = gear.rods[item.name]
        if rod then
            local durability = tonumber(item.metadata and item.metadata.durability) or rod.durability
            repair = repair + math.max(0, rod.durability - durability) * gear.repairPerPoint
        end
    end

    return true, {
        level = profile.level,
        discount = levels.value(profile.skills, 'discount'),
        licence = {
            valid = valid,
            expiresText = expires and os.date('%Y-%m-%d %H:%M', expires) or nil,
            price = discounted(gear.licence.price, profile.skills),
        },
        repair = repair,
        respec = settings.respec.price,
    }
end)

lib.callback.register('city_fishing:buy', function(source, name, count)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local entry = type(name) == 'string' and catalogueEntry(name)
    count = math.tointeger(count)
    if not entry or not count or count < 1 or count > MAX_COUNT[entry.kind] then return false, 'invalid' end
    if not atShop(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    if profile.level < entry.level then return false, 'level_low' end

    local metadata
    if entry.kind == 'rod' then metadata = { durability = gear.rods[name].durability, tackle = {} } end

    if not exports.city_inventory:CanCarryItem(src, name, count, metadata) then return false, 'inventory_full' end

    local price = discounted(entry.price, profile.skills) * count
    if not util.pay(src, price, 'fishing-shop') then return false, 'no_money' end

    exports.city_inventory:AddItem(src, name, count, metadata)

    return true, price
end)

lib.callback.register('city_fishing:buyLicence', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    local price = discounted(gear.licence.price, profile.skills)
    local _, expires = util.licence(src, citizenid)
    local from = math.max(os.time(), expires or 0)

    local metadata = {
        citizenid = citizenid,
        holder = util.name(src),
        expires = from + gear.licence.days * 86400,
    }
    metadata.description = ('%s · valid until %s'):format(metadata.holder, os.date('%Y-%m-%d %H:%M', metadata.expires))

    if not exports.city_inventory:CanCarryItem(src, gear.licence.item, 1, metadata) then return false, 'inventory_full' end
    if not util.pay(src, price, 'fishing-licence') then return false, 'no_money' end

    -- The old licence of this character is replaced by the extended one
    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, gear.licence.item) or {}) do
        if slot.metadata and slot.metadata.citizenid == citizenid then
            exports.city_inventory:RemoveItem(src, gear.licence.item, 1, nil, slot.slot)
        end
    end

    exports.city_inventory:AddItem(src, gear.licence.item, 1, metadata)

    return true, metadata.expires
end)

lib.callback.register('city_fishing:repair', function(source)
    local src = source
    local player = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    local cost, rods = 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local rod = gear.rods[item.name]

        if rod then
            local metadata = item.metadata or {}
            local durability = tonumber(metadata.durability) or rod.durability

            if durability < rod.durability then
                cost = cost + (rod.durability - durability) * gear.repairPerPoint
                metadata.durability = rod.durability
                rods[#rods + 1] = { slot = item.slot, metadata = metadata }
            end
        end
    end

    if #rods == 0 then return false, 'nothing_to_repair' end
    if not util.pay(src, cost, 'fishing-repair') then return false, 'no_money' end

    for _, rod in ipairs(rods) do
        exports.city_inventory:SetMetadata(src, rod.slot, rod.metadata)
    end

    return true, cost
end)

lib.callback.register('city_fishing:respec', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atShop(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    if next(profile.skills) == nil then return false, 'nothing_to_reset' end
    if not util.pay(src, settings.respec.price, 'fishing-respec') then return false, 'no_money' end

    profile.skills = {}
    profiles.save(profile)

    return true
end)
