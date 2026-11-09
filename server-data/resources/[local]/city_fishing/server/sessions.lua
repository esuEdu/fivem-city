-- A catch, from the cast to the result. The client only sends the bobber position, the hook press and the minigame
-- result; the server decides the wait, what bites, its size, stars, XP and the chest loot.
local settings = require 'server.config'
local fish = require 'server.fish'
local regions = require 'server.regions'
local catch = require 'server.catch'
local profiles = require 'server.profiles'
local util = require 'server.util'
local frenzy = require 'server.frenzy'
local tournaments = require 'server.tournaments'
local gear = require 'shared.gear'
local levels = require 'shared.levels'

---@type table<integer, table>
local active = {}
local nextId = 0

local function newId()
    nextId = nextId + 1
    return nextId
end

---@param level integer
---@return number metres
local function castRange(level)
    local range = Config.CastRange

    for _, at in ipairs(Config.CastRangeLevels) do
        if level >= at then range = range + 1.0 end
    end

    return range
end

---@param value unknown
---@return vector3?
local function toVector(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return end

    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then return end

    return vector3(x, y, z)
end

---@param src integer
---@param state table
---@param firstBite boolean
---@return integer ms
local function rollWait(src, state, firstBite)
    state.ctx.firstBite = firstBite
    state.waitMs = math.floor(catch.biteSeconds(state.ctx, settings.wait) * 1000)
    state.castAt = GetGameTimer()

    return state.waitMs
end

---Rolled chest loot: a few entries by weight, gated by shore distance and level.
---@param shore integer
---@param level integer
---@return { item: string, count: integer }[]
local function rollLoot(shore, level)
    local pool, total = {}, 0

    for _, entry in ipairs(settings.loot.items) do
        if shore >= (entry.minShore or 0) and level >= (entry.minLevel or 0) then
            pool[#pool + 1] = entry
            total = total + entry.weight
        end
    end

    local loot = {}
    if total == 0 then return loot end

    for _ = 1, math.random(settings.loot.rolls[1], settings.loot.rolls[2]) do
        local pick = math.random() * total

        for _, entry in ipairs(pool) do
            pick = pick - entry.weight

            if pick <= 0 then
                loot[#loot + 1] = { item = entry.item, count = math.random(entry.count[1], entry.count[2]) }
                break
            end
        end
    end

    return loot
end

---@param src integer
---@param item string
---@param count integer
---@param metadata? table
---@return boolean
local function give(src, item, count, metadata)
    if not exports.city_inventory:CanCarryItem(src, item, count, metadata) then
        util.notify(src, 'inventory_full', 'error')
        return false
    end

    return exports.city_inventory:AddItem(src, item, count, metadata) == true
end

---Wears the rod's tackle by one bite; worn-out pieces fall off.
---@param src integer
---@param state table
local function wearTackle(src, state)
    local item = util.rod(src, state.slot)
    local metadata = item and item.metadata or {}
    if type(metadata.tackle) ~= 'table' or #metadata.tackle == 0 then return end

    local kept = {}
    for _, piece in ipairs(metadata.tackle) do
        piece.uses = (tonumber(piece.uses) or gear.tackleUses) - 1
        if piece.uses > 0 then kept[#kept + 1] = piece else util.notify(src, 'tackle_worn', 'inform') end
    end

    metadata.tackle = kept
    exports.city_inventory:SetMetadata(src, state.slot, metadata)
end

lib.callback.register('city_fishing:cast', function(source, slot, bobberData, measuredShore)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local item, rod = util.rod(src, slot)
    if not item then return false, 'no_rod' end

    local metadata = item.metadata or {}
    local durability = tonumber(metadata.durability) or rod.durability
    if durability <= 0 then return false, 'rod_broken' end

    local now = GetGameTimer()
    local previous = active[src]
    if previous and previous.lastCast and now - previous.lastCast < settings.cast.cooldownMs then return false, 'too_fast' end

    local needs = player.PlayerData.metadata
    if (needs.hunger or 100) < settings.cast.minStatus or (needs.thirst or 100) < settings.cast.minStatus then
        return false, 'too_weak'
    end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then return false, 'driving' end

    local bobber = toVector(bobberData)
    local origin = GetEntityCoords(ped)
    local profile = profiles.get(citizenid)

    if not bobber or #(bobber.xy - origin.xy) > castRange(profile.level) + 2.0 then
        lib.print.warn(('Player %s cast to an invalid spot'):format(src))
        return false, 'invalid'
    end

    -- Bait: one per cast, only on rods that take it
    local baitName, bait = metadata.bait, nil
    if rod.bait and type(baitName) == 'string' and gear.baits[baitName] and exports.city_inventory:GetItemCount(src, baitName) > 0 then
        if exports.city_inventory:RemoveItem(src, baitName, 1) then bait = gear.baits[baitName] end
    end

    metadata.durability = durability - 1
    exports.city_inventory:SetMetadata(src, slot, metadata)

    util.drain(src, 'hunger', settings.cast.hunger)
    util.drain(src, 'thirst', settings.cast.thirst)
    TriggerClientEvent('hud:client:UpdateNeeds', src, player.PlayerData.metadata.hunger, player.PlayerData.metadata.thirst)

    local region = regions.at(bobber.x, bobber.y)
    local tackle = rod.slots > 0 and metadata.tackle or nil

    local state = {
        id = newId(),
        slot = slot,
        citizenid = citizenid,
        origin = origin,
        bobber = bobber,
        lastCast = now,
        ctx = {
            region = region,
            shore = regions.shore(region, measuredShore),
            level = profile.level,
            skills = profile.skills,
            bait = bait,
            baitName = bait and baitName or nil,
            effects = gear.tackleEffects(tackle),
            frenzy = frenzy.speciesAt(bobber, region),
            atSpot = function(id) return Config.Features.legendary and regions.atSpot(id, bobber.x, bobber.y) end,
        },
    }

    active[src] = state

    return true, { cast = state.id, waitMs = rollWait(src, state, true), region = region }
end)

-- The bite was missed: the fish swims off and another one comes later
lib.callback.register('city_fishing:rebite', function(source, castId)
    local src = source
    local state = active[src]
    if not state or state.id ~= castId or state.session then return false end

    if GetGameTimer() - state.castAt < state.waitMs then return false end

    return true, rollWait(src, state, false)
end)

lib.callback.register('city_fishing:hook', function(source, castId)
    local src = source
    local state = active[src]
    if not state or state.id ~= castId or state.session then return false end

    local elapsed = GetGameTimer() - state.castAt
    if elapsed < state.waitMs - 250 or elapsed > state.waitMs + Config.HookWindow * 1000 + settings.session.latencyMs then
        return false, 'missed'
    end

    local ctx = state.ctx
    ctx.hour = util.hour()
    ctx.weather = util.weather()

    local entry = catch.pick(fish.list, ctx, settings)
    if not entry then return false, 'missed' end

    if entry.kind ~= 'fish' then
        active[src] = { lastCast = state.lastCast }

        if not give(src, entry.name, 1) then return true, { kind = 'lost' } end

        local profile = profiles.get(state.citizenid)
        local levelUp = profiles.addXp(profile, catch.xp(entry))
        if not entry.junk then profiles.record(profile, entry, nil) end

        return true, { kind = 'item', label = entry.label, levelUp = levelUp }
    end

    wearTackle(src, state)

    local chest = Config.Features.chests and catch.rollChest(ctx, settings.chest)
    local challenge = ctx.bait and ctx.bait.challenge or false

    state.session = {
        id = newId(),
        entry = entry,
        chest = chest,
        challenge = challenge,
        startedAt = GetGameTimer(),
    }

    return true, {
        kind = 'fish',
        session = state.session.id,
        difficulty = entry.difficulty,
        behavior = entry.behavior,
        bar = catch.bar(ctx, Config.Minigame),
        chest = chest,
        chestDelay = math.random(1000, 3000),
        crown = entry.legendary ~= nil,
        label = (ctx.effects.sonar or levels.value(ctx.skills, 'sonar') > 0) and entry.label or nil,
        trap = ctx.effects.trap,
        lead = ctx.effects.lead,
        barbed = ctx.effects.barbed,
        challenge = challenge,
    }
end)

lib.callback.register('city_fishing:finish', function(source, sessionId, result)
    local src = source
    local state = active[src]
    local session = state and state.session
    if not session or session.id ~= sessionId or type(result) ~= 'table' then return false end

    active[src] = { lastCast = state.lastCast }

    if result.caught ~= true then return true, { kind = 'escaped' } end

    local elapsed = GetGameTimer() - session.startedAt
    if elapsed < catch.minMs(Config.Minigame) - settings.session.latencyMs or elapsed > settings.session.maxSeconds * 1000 then
        lib.print.warn(('Player %s finished a catch in %d ms, refused'):format(src, elapsed))
        return false
    end

    if not util.near(src, state.origin, settings.session.maxMove) or not util.rod(src, state.slot) then return false end

    local entry, ctx = session.entry, state.ctx
    local perfect = result.perfect == true
    local chestTaken = session.chest and result.chest == true
    local outside = math.max(0, math.min(tonumber(result.outside) or 0, elapsed / 1000))
    local escapes = math.max(0, math.min(math.tointeger(result.escapes) or 0, 3))

    local factor = catch.factor(ctx)
    local size = catch.size(entry, factor, outside, perfect)
    local stars = catch.stars(factor, ctx.effects.quality or 0, perfect)
    local baseStars = catch.stars(factor, ctx.effects.quality or 0, false)

    local count = 1
    if session.challenge then
        if escapes >= 3 then return true, { kind = 'escaped' } end
        if perfect then count = 3 - escapes end
    elseif ctx.bait and ctx.bait.double and not entry.legendary and math.random() < ctx.bait.double then
        count = 2
    end

    if not give(src, entry.name, count, { quality = stars }) then return true, { kind = 'lost' } end

    local loot = chestTaken and rollLoot(ctx.shore, ctx.level) or {}
    for _, drop in ipairs(loot) do give(src, drop.item, drop.count) end

    local profile = profiles.get(state.citizenid)
    local record = profiles.record(profile, entry, size)
    local levelUp = profiles.addXp(profile, catch.xp(entry, baseStars, chestTaken, perfect) * count)

    if entry.legendary then
        TriggerClientEvent('city_fishing:client:announce', -1, 'legendary_caught', util.name(src), entry.label, size)
    end

    tournaments.onCatch(src, state.citizenid, entry, size, count, state.bobber, ctx.region)

    return true, {
        kind = 'fish',
        label = entry.label,
        size = size,
        stars = stars,
        count = count,
        perfect = perfect,
        record = record,
        loot = #loot,
        levelUp = levelUp,
    }
end)

RegisterNetEvent('city_fishing:server:stop', function()
    local src = source
    local state = active[src]
    if state then active[src] = { lastCast = state.lastCast } end
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
end)
