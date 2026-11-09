-- The Mining app on the iFruit tablet: profile, skill tree, buyer prices and open orders. Every callback works out the
-- character from source.
local gear = require 'shared.gear'
local levels = require 'shared.levels'
local profiles = require 'server.profiles'
local orders = require 'server.orders'
local demand = require 'server.demand'
local veins = require 'server.veins'
local util = require 'server.util'

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/app/index.html',
        icon = Config.App.icon,
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

lib.callback.register('city_mining:app:profile', function(source)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid then return false end

    local profile = profiles.get(citizenid)
    local valid, expires = util.licence(src, citizenid, gear.licence.item)

    return true, {
        level = profile.level,
        max = levels.max,
        xp = profile.xp,
        from = levels.xpFor(profile.level),
        to = profile.level < levels.max and levels.xpFor(profile.level + 1) or nil,
        points = levels.points(profile.level) - levels.spent(profile.skills),
        skills = profile.skills,
        mined = profile.mined,
        geodes = profile.geodes,
        panned = profile.panned,
        tiers = gear.tierLevels,
        licence = { valid = valid, expires = expires, now = os.time() },
    }
end)

lib.callback.register('city_mining:app:learn', function(source, id)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid or type(id) ~= 'string' then return false end

    local profile = profiles.get(citizenid)
    local ok, reason = levels.canLearn(profile.skills, profile.level, id)
    if not ok then return false, reason end

    profile.skills[id] = (profile.skills[id] or 0) + 1
    profiles.save(profile)

    return true, profile.skills
end)

lib.callback.register('city_mining:app:market', function(source)
    if not util.player(source) then return false end

    local list = demand.prices()
    for _, entry in ipairs(list) do
        local item = exports.city_inventory:Items(entry.name)
        entry.label = item and item.label or entry.name
    end

    return true, list
end)

lib.callback.register('city_mining:app:orders', function(source)
    local _, citizenid = util.player(source)
    if not citizenid then return false end

    local list = {}
    for _, row in ipairs(orders.list(citizenid)) do
        local kind, name = row.recipe:match('^(%a+):(.+)$')
        local item = exports.city_inventory:Items(name or row.recipe)

        list[#list + 1] = {
            place = row.place:match('^home') and 'home' or row.place,
            kind = kind or 'smelt',
            label = item and item.label or row.recipe,
            count = row.count,
            secondsLeft = math.max(0, row.ready_at - os.time()),
        }
    end

    return true, list
end)

-- Geologist's tracking node: nearby veins the player can mine, as temporary blips
lib.callback.register('city_mining:track', function(source)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid then return false end

    local profile = profiles.get(citizenid)
    if profiles.skill(profile, 'tracking') <= 0 then return false, 'no_tracking' end

    local origin = GetEntityCoords(GetPlayerPed(src))
    local list = {}

    for _, vein in pairs(veins.active) do
        local c = vein.point.coords
        if vein.kind == 'vein' and #(c.xyz - origin) <= 80.0 and profile.level >= gear.tierLevels[vein.tier] then
            list[#list + 1] = { x = c.x, y = c.y, z = c.z, tier = vein.tier }
        end
    end

    return true, list
end)
