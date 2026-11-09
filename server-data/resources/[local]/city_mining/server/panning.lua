-- Panning in the rivers: a pan at an active gravel spot (band minigame, then the spot moves on), and the sluice box
-- (Golden Pan capstone) that works a spot on its own while its owner stays close.
local settings = require 'server.config'
local gear = require 'shared.gear'
local veins = require 'server.veins'
local profiles = require 'server.profiles'
local rolls = require 'server.rolls'
local luck = require 'server.luck'
local session = require 'server.session'
local util = require 'server.util'

---@type table<string, integer> citizenid -> GetGameTimer() of the last pan
local lastPan = {}
---@type table<integer, table> src -> sluice
local sluices = {}

---@param profile table
---@return table ctx for rolls.pan
local function ctxFor(profile)
    return { luck = luck.get(), skill = function(id) return profiles.skill(profile, id) end }
end

lib.callback.register('city_mining:panStart', function(source, id)
    if not Config.Features.panning then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    id = math.tointeger(id)
    local spot = id and veins.active[id]
    if not spot or spot.kind ~= 'gravel' then return false, 'vein_gone' end

    local unable = util.unable(src, player)
    if unable then return false, unable end
    if not util.near(src, spot.point.coords, settings.panning.range) then return false, 'too_far' end

    local pan = util.tool(src, gear.pan.item)
    if not pan then return false, 'no_pan' end

    local profile = profiles.get(citizenid)
    local wait = settings.panning.wait * (1 - profiles.skill(profile, 'pan_wait')) * 1000
    if lastPan[citizenid] and GetGameTimer() - lastPan[citizenid] < wait then return false, 'too_fast' end

    local factor = 1 - profiles.skill(profile, 'pan_speed')
    local opened = session.open(src, 'pan', { spot = id, slot = pan.slot, factor = factor })

    return true, { session = opened, factor = factor }
end)

lib.callback.register('city_mining:panFinish', function(source, sessionId, kept)
    if not Config.Features.panning then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local current = session.take(src, 'pan', sessionId)
    if not current then return false, 'invalid' end

    local panning = settings.panning
    if not session.timed(current, panning.minSeconds * current.factor, panning.maxSeconds) then
        lib.print.warn(('city_mining: %s (%s) finished a pan too fast or too late'):format(citizenid, src))
        return false, 'invalid'
    end

    local spot = veins.active[current.spot]
    if not spot or spot.kind ~= 'gravel' then return false, 'vein_gone' end
    if not util.near(src, spot.point.coords, panning.range + 1.0) then return false, 'too_far' end

    local pan = exports.city_inventory:GetSlot(src, current.slot)
    if not pan or pan.name ~= gear.pan.item then return false, 'no_pan' end

    local profile = profiles.get(citizenid)
    kept = math.max(0, math.min(1, tonumber(kept) or 0))

    -- Losing the band spills the good gravel: the less was kept, the likelier only junk is left
    local drop
    if math.random() > kept + 0.3 then
        drop = { item = 'metalscrap', count = 1 }
    else
        drop = rolls.pan(panning.drops, ctxFor(profile), math.random)
    end

    if not util.giveAll(src, { drop }) then return false, 'inventory_full' end

    veins.take(current.spot)
    lastPan[citizenid] = GetGameTimer()

    local wear = 1
    if util.count(src, 'mining_gloves') > 0 then wear = 1 - settings.ppe.gloves end
    util.wear(src, pan, wear)

    profile.panned = profile.panned + 1
    local levelUp = profiles.addXp(profile, panning.xp)

    return true, { drops = { drop }, levelUp = levelUp }
end)

-- The sluice box: placed at an active gravel spot by its owner, one cycle every sluice.cycleSeconds
exports.qbx_core:CreateUseableItem(gear.sluice.item, function(source)
    if not Config.Features.panning then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    if sluices[src] then return util.notify(src, 'sluice_running', 'error') end
    if profiles.skill(profiles.get(citizenid), gear.sluice.skill) <= 0 then return util.notify(src, 'needs_golden_pan', 'error') end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local spot
    for _, vein in pairs(veins.active) do
        if vein.kind == 'gravel' and #(vein.point.coords.xyz - coords) <= settings.panning.range then spot = vein break end
    end
    if not spot then return util.notify(src, 'sluice_needs_gravel', 'error') end

    -- The box stays in the inventory while it works, so leaving or crashing never loses it
    sluices[src] = { citizenid = citizenid, coords = spot.point.coords.xyz, started = os.time(), next = os.time() + settings.sluice.cycleSeconds }
    TriggerClientEvent('city_mining:client:sluice', src, { x = spot.point.coords.x, y = spot.point.coords.y, z = spot.point.coords.z })
    util.notify(src, 'sluice_placed', 'success')

    return false
end)

---@param src integer
---@param key string? notification
local function endSluice(src, key)
    local sluice = sluices[src]
    if not sluice then return end

    sluices[src] = nil

    if GetPlayerName(src) then
        TriggerClientEvent('city_mining:client:sluice', src, nil)
        if key then util.notify(src, key, 'inform') end
    end
end

CreateThread(function()
    while true do
        Wait(5000)

        local now = os.time()

        for src, sluice in pairs(sluices) do
            if not GetPlayerName(src) then
                sluices[src] = nil
            elseif util.count(src, gear.sluice.item) == 0 then
                endSluice(src, 'sluice_left')
            elseif not util.near(src, sluice.coords, settings.sluice.range) then
                endSluice(src, 'sluice_left')
            elseif now - sluice.started >= settings.sluice.maxMinutes * 60 then
                endSluice(src, 'sluice_done')
            elseif now >= sluice.next then
                sluice.next = now + settings.sluice.cycleSeconds

                local profile = profiles.get(sluice.citizenid)
                local drop = rolls.pan(settings.panning.drops, ctxFor(profile), math.random)

                if util.giveAll(src, { drop }) then
                    profiles.addXp(profile, settings.sluice.xp)
                else
                    endSluice(src, 'inventory_full')
                end
            end
        end
    end
end)

RegisterNetEvent('city_mining:server:stopSluice', function()
    endSluice(source)
end)

AddEventHandler('playerDropped', function()
    sluices[source] = nil
end)
