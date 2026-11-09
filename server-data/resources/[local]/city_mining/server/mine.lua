-- Mining a vein, from the first strike to the drop. The client sends the vein id and, at the end, how many strikes were
-- perfect; the server checks distance, tool, level and time, and decides what the vein gives.
local settings = require 'server.config'
local gear = require 'shared.gear'
local veins = require 'server.veins'
local points = require 'server.points'
local profiles = require 'server.profiles'
local rolls = require 'server.rolls'
local luck = require 'server.luck'
local session = require 'server.session'
local util = require 'server.util'

lib.callback.register('city_mining:start', function(source, id)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    id = math.tointeger(id)
    local vein = id and veins.active[id]
    if not vein or vein.kind ~= 'vein' then return false, 'vein_gone' end

    local unable = util.unable(src, player)
    if unable then return false, unable end
    if not util.near(src, vein.point.coords, settings.mining.range) then return false, 'too_far' end

    local region = points.regions[vein.region]
    if region.passage and not veins.passageOpen(region.id) then return false, 'passage_closed' end

    local profile = profiles.get(citizenid)
    if profile.level < gear.tierLevels[vein.tier] then return false, 'level_low_tier', gear.tierLevels[vein.tier] end

    local slot, pickaxe = util.bestPickaxe(src)
    if not slot then return false, 'no_pickaxe' end
    if pickaxe.tier < vein.tier then return false, 'pickaxe_weak' end

    local factor = pickaxe.speed * (1 - profiles.skill(profile, 'speed'))
    local opened = session.open(src, 'vein', { vein = vein.point.id, slot = slot.slot, factor = factor })

    return true, { session = opened, factor = factor, tier = vein.tier, ore = vein.ore }
end)

lib.callback.register('city_mining:finish', function(source, sessionId, perfect)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local current = session.take(src, 'vein', sessionId)
    if not current then return false, 'invalid' end

    local mining = settings.mining
    if not session.timed(current, mining.minSeconds * current.factor, mining.maxSeconds) then
        lib.print.warn(('city_mining: %s (%s) finished a vein too fast or too late'):format(citizenid, src))
        return false, 'invalid'
    end

    local vein = veins.active[current.vein]
    if not vein then return false, 'vein_gone' end
    if not util.near(src, vein.point.coords, mining.range + 1.0) then return false, 'too_far' end

    local slot = exports.city_inventory:GetSlot(src, current.slot)
    local pickaxe = slot and gear.pickaxes[slot.name]
    if not pickaxe or pickaxe.tier < vein.tier then return false, 'no_pickaxe' end

    local profile = profiles.get(citizenid)
    local mined = profiles.recentVeins(citizenid)
    perfect = math.max(0, math.min(Config.Minigame.strikes, math.tointeger(perfect) or 0))

    local drops = rolls.vein(settings.tiers[vein.tier], vein.ore, {
        perfect = perfect,
        strikes = Config.Minigame.strikes,
        luck = luck.get(),
        mined = mined,
        skill = function(id) return profiles.skill(profile, id) end,
        settings = settings,
    }, math.random)

    if not Config.Features.geodes then
        local kept = {}
        for _, drop in ipairs(drops) do
            if not settings.geodes[drop.item] then kept[#kept + 1] = drop end
        end
        drops = kept
    end

    if not util.giveAll(src, drops) then return false, 'inventory_full' end

    veins.take(current.vein)
    profiles.countVein(citizenid)

    local wear = 1 - profiles.skill(profile, 'wear')
    if util.count(src, 'mining_gloves') > 0 then wear = wear * (1 - settings.ppe.gloves) end
    util.wear(src, slot, wear)

    profile.mined = profile.mined + 1
    for _, drop in ipairs(drops) do
        if settings.geodes[drop.item] then profile.geodes = profile.geodes + 1 end
    end

    local levelUp = profiles.addXp(profile, settings.tiers[vein.tier].xp)

    return true, { drops = drops, levelUp = levelUp, tired = mined >= mining.softCap }
end)

RegisterNetEvent('city_mining:server:stop', function()
    session.clear(source)
end)

AddEventHandler('playerDropped', function()
    session.clear(source)
end)
