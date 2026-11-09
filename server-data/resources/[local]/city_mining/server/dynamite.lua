-- Dynamite: breaks super rocks, opens the blocked passage for a while, and can be set off anywhere (a police call
-- outside the mining regions). Galleries can cave in, more often right after a blast; a trapped player waits for
-- someone to dig them out.
local settings = require 'server.config'
local points = require 'server.points'
local veins = require 'server.veins'
local profiles = require 'server.profiles'
local rolls = require 'server.rolls'
local luck = require 'server.luck'
local util = require 'server.util'

---@type table<string, integer> region -> os.time() of the last blast
local lastBlast = {}

---Takes one dynamite: the legal kind first. Returns the item used.
---@param src integer
---@return string? item
local function takeDynamite(src)
    for _, name in ipairs({ 'dynamite', 'homemade_dynamite' }) do
        if util.count(src, name) > 0 and exports.city_inventory:RemoveItem(src, name, 1) then return name end
    end
end

---@param src integer
---@param coords vector3
local function alertIfOutside(src, coords)
    if points.regionAt(coords) then return end
    if GetResourceState('city_police') ~= 'started' then return end

    exports.city_police:Alert({
        title = locale('alert_explosion'),
        text = locale('alert_explosion_text'),
        coords = coords,
        code = '10-80',
        priority = 2,
    })
end

---A homemade one may go off early in the hand.
---@param src integer
---@param item string
---@return boolean failed
local function misfire(src, item)
    if item ~= 'homemade_dynamite' or math.random() >= settings.dynamite.homemadeFail then return false end

    TriggerClientEvent('city_mining:client:blast', src, nil, settings.dynamite.failDamage)
    alertIfOutside(src, GetEntityCoords(GetPlayerPed(src)))

    return true
end

lib.callback.register('city_mining:blast', function(source, kind, regionId)
    if not Config.Features.dynamite then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local region = type(regionId) == 'string' and points.regions[regionId]
    if not region or (kind ~= 'super' and kind ~= 'passage') then return false, 'invalid' end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local target

    if kind == 'super' then
        local id = veins.super[region.id]
        local point = id and points.byId[id]
        if not point or #(point.coords.xyz - coords) > settings.superRocks.range then return false, 'too_far' end
        target = point.coords.xyz
    else
        local point = points.of(region.id, 'passage')[1]
        if not point or #(point.coords.xyz - coords) > settings.dynamite.passageRange then return false, 'too_far' end
        if veins.passageOpen(region.id) then return false, 'passage_open' end
        target = point.coords.xyz
    end

    local item = takeDynamite(src)
    if not item then return false, 'no_dynamite' end
    if misfire(src, item) then return false, 'dynamite_failed' end

    lastBlast[region.id] = os.time()
    TriggerClientEvent('city_mining:client:blast', -1, { x = target.x, y = target.y, z = target.z }, 0)

    if kind == 'passage' then
        veins.openPassage(region.id, settings.dynamite.passageMinutes)
        return true, { opened = true }
    end

    local profile = profiles.get(citizenid)
    local tier = veins.mainTier(region)
    local ore = rolls.weighted(settings.tiers[tier].ores, math.random).item
    local drops = rolls.superRock(settings.tiers[tier], ore, settings.superRocks, luck.get(), math.random)

    veins.breakSuper(region.id)

    -- What doesn't fit stays on the ground for anyone to pick up
    for _, drop in ipairs(drops) do
        local fits = exports.city_inventory:CanCarryItem(src, drop.item, drop.count)
        if fits then
            exports.city_inventory:AddItem(src, drop.item, drop.count)
        elseif GetResourceState('city_inventory') == 'started' then
            exports.city_inventory:CustomDrop(locale('super_rock'), { { drop.item, drop.count } }, target)
        end
    end

    local levelUp = profiles.addXp(profile, settings.superRocks.xp)

    return true, { drops = drops, levelUp = levelUp }
end)

-- Using dynamite anywhere else: a blast in front of the player after a short fuse
local function useDynamite(source, item)
    local src = source
    if not Config.Features.dynamite then return false end
    if not util.player(src) then return false end

    TriggerClientEvent('city_mining:client:plantDynamite', src, item.name)

    return false
end

exports.qbx_core:CreateUseableItem('dynamite', useDynamite)
exports.qbx_core:CreateUseableItem('homemade_dynamite', useDynamite)

lib.callback.register('city_mining:plant', function(source, name, at)
    if not Config.Features.dynamite then return false end
    local src = source
    if not util.player(src) then return false end
    if name ~= 'dynamite' and name ~= 'homemade_dynamite' then return false, 'invalid' end

    local x, y, z = type(at) == 'table' and tonumber(at.x), type(at) == 'table' and tonumber(at.y), type(at) == 'table' and tonumber(at.z)
    if not x or not y or not z then return false, 'invalid' end

    local target = vec3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - target) > settings.dynamite.throwRange then return false, 'too_far' end

    if util.count(src, name) == 0 or not exports.city_inventory:RemoveItem(src, name, 1) then return false, 'no_dynamite' end
    if misfire(src, name) then return false, 'dynamite_failed' end

    local region = points.regionAt(target)
    if region then lastBlast[region.id] = os.time() end

    alertIfOutside(src, target)
    TriggerClientEvent('city_mining:client:blast', -1, { x = x, y = y, z = z }, 0)

    return true
end)

-- Cave-ins
---@param region table
---@return integer[] players inside the region's area
local function playersIn(region)
    local area = points.areas[region.id]
    if not area then return {} end

    local inside = {}

    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local ped = GetPlayerPed(src)
        if ped ~= 0 and #(GetEntityCoords(ped) - area.center) <= area.radius then inside[#inside + 1] = src end
    end

    return inside
end

---@param region table
local function caveIn(region)
    local players = playersIn(region)
    if #players == 0 then return end

    local caves = settings.caveIns
    for _, src in ipairs(players) do TriggerClientEvent('city_mining:client:caveWarning', src, caves.warningSeconds) end

    SetTimeout(caves.warningSeconds * 1000, function()
        veins.closePassage(region.id)

        for _, src in ipairs(playersIn(region)) do
            local helmet = Player(src).state.miningHelmet and util.count(src, 'mining_helmet') > 0
            Player(src).state:set('miningTrapped', os.time() + caves.trappedSeconds, true)
            TriggerClientEvent('city_mining:client:caveIn', src, helmet and caves.helmetDamage or caves.damage, caves.trappedSeconds)
        end
    end)
end

CreateThread(function()
    local caves = settings.caveIns

    while true do
        Wait(caves.checkMinutes * 60000)

        if not Config.Features.dynamite then goto continue end

        for _, region in ipairs(Config.Regions) do
            if region.gallery then
                local recent = lastBlast[region.id] and os.time() - lastBlast[region.id] <= caves.blastSeconds
                if math.random() < (recent and caves.afterBlast or caves.chance) then caveIn(region) end
            end
        end

        ::continue::
    end
end)

lib.callback.register('city_mining:rescue', function(source, target)
    if not Config.Features.dynamite then return false end
    local src = source
    if not util.player(src) then return false end

    target = math.tointeger(target)
    if not target or target == src or not GetPlayerName(target) then return false, 'invalid' end
    if not Player(target).state.miningTrapped then return false, 'invalid' end

    local ped, other = GetPlayerPed(src), GetPlayerPed(target)
    if #(GetEntityCoords(ped) - GetEntityCoords(other)) > settings.caveIns.rescueRange then return false, 'too_far' end

    Player(target).state:set('miningTrapped', nil, true)
    util.notify(target, 'rescued', 'success')

    return true
end)

-- Trapped players are freed when the time runs out
CreateThread(function()
    while true do
        Wait(5000)

        local now = os.time()
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local trapped = Player(src).state.miningTrapped
            if trapped and trapped <= now then Player(src).state:set('miningTrapped', nil, true) end
        end
    end
end)
