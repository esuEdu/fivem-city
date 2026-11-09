-- The public smelter at Stoner Cement Works: smelting orders (stamped ingots, fee), coal and dynamite sales. Needs a
-- valid mining licence; dynamite needs the explosives licence the police granted.
local settings = require 'server.config'
local gear = require 'shared.gear'
local profiles = require 'server.profiles'
local orders = require 'server.orders'
local smelting = require 'server.smelting'
local util = require 'server.util'

local PLACE = 'smelter'

---@param src integer
---@return boolean
local function atSmelter(src)
    return util.near(src, Config.Smelter.coords, settings.smelter.range)
end

---@param profile table
---@return integer dynamite left today
local function dynamiteLeft(profile)
    if profile.dynamiteDay ~= util.today() then return gear.dynamite.perDay end

    return math.max(0, gear.dynamite.perDay - profile.dynamiteCount)
end

lib.callback.register('city_mining:smelterInfo', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player or not atSmelter(src) then return false end

    local profile = profiles.get(citizenid)
    local recipes = {}

    for name, recipe in pairs(settings.recipes) do
        if not recipe.homeOnly then
            local quote = smelting.quote(profile, name, 1, false)
            recipes[#recipes + 1] = { name = name, inputs = quote.inputs, fee = quote.fee, seconds = quote.seconds, stamped = settings.ingots[name] == true }
        end
    end

    table.sort(recipes, function(a, b) return a.seconds < b.seconds end)

    local explosivesValid = util.licence(src, citizenid, gear.explosives.item) and util.explosivesGranted(player)

    return true, {
        licence = util.licence(src, citizenid, gear.licence.item),
        order = smelting.view(orders.get(citizenid, PLACE)),
        recipes = recipes,
        maxBatch = smelting.maxBatch(profile, false),
        coal = gear.coal.price,
        dynamite = { allowed = explosivesValid, price = gear.dynamite.price, left = dynamiteLeft(profile) },
    }
end)

lib.callback.register('city_mining:smelt', function(source, name, count)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atSmelter(src) then return false, 'too_far' end
    if not util.licence(src, citizenid, gear.licence.item) then return false, 'no_licence' end

    return smelting.start(src, citizenid, PLACE, name, count, false)
end)

lib.callback.register('city_mining:collect', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atSmelter(src) then return false, 'too_far' end

    local order = orders.get(citizenid, PLACE)
    if not order then return false, 'no_order' end

    return smelting.collect(src, citizenid, order)
end)

lib.callback.register('city_mining:buyCoal', function(source, count)
    local src = source
    if not util.player(src) then return false end
    if not atSmelter(src) then return false, 'too_far' end

    count = math.tointeger(count)
    if not count or count < 1 or count > 100 then return false, 'invalid' end

    if not exports.city_inventory:CanCarryItem(src, gear.coal.item, count) then return false, 'inventory_full' end
    if not util.pay(src, gear.coal.price * count, 'mining-coal') then return false, 'no_money' end

    exports.city_inventory:AddItem(src, gear.coal.item, count)

    return true, gear.coal.price * count
end)

lib.callback.register('city_mining:buyDynamite', function(source, count)
    if not Config.Features.dynamite then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atSmelter(src) then return false, 'too_far' end

    count = math.tointeger(count)
    if not count or count < 1 then return false, 'invalid' end

    if not util.explosivesGranted(player) or not util.licence(src, citizenid, gear.explosives.item) then return false, 'no_explosives_licence' end

    local profile = profiles.get(citizenid)
    if count > dynamiteLeft(profile) then return false, 'dynamite_limit' end

    if not exports.city_inventory:CanCarryItem(src, gear.dynamite.item, count) then return false, 'inventory_full' end
    if not util.pay(src, gear.dynamite.price * count, 'mining-dynamite') then return false, 'no_money' end

    if profile.dynamiteDay ~= util.today() then
        profile.dynamiteDay = util.today()
        profile.dynamiteCount = 0
    end

    profile.dynamiteCount = profile.dynamiteCount + count
    profiles.save(profile)
    exports.city_inventory:AddItem(src, gear.dynamite.item, count)

    lib.print.info(('city_mining: %s bought %d dynamite'):format(citizenid, count))

    return true, gear.dynamite.price * count
end)
