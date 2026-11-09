-- Start-up (tables, points, veins), the server clock, usable items and saving profiles.
local settings = require 'server.config'
local points = require 'server.points'
local veins = require 'server.veins'
local profiles = require 'server.profiles'
local orders = require 'server.orders'
local util = require 'server.util'

local ready = false

MySQL.ready(function()
    profiles.init()
    points.init()
    orders.init()
    orders.expire(settings.smelter.pickupHours)

    GlobalState.miningAreas = points.publicAreas()
    veins.fill()
    ready = true

    TriggerEvent('city_mining:server:ready')
end)

-- One clock for veins (30 s), super rocks and saving profiles
CreateThread(function()
    local ticks = 0

    while true do
        Wait(30000)

        if ready then
            ticks = ticks + 1
            veins.tick()

            if ticks % 2 == 0 then profiles.flush() end
            if ticks % (settings.superRocks.checkMinutes * 2) == 0 then veins.rollSuperRocks() end
        end
    end
end)

-- The helmet is put on and taken off by using it; the lamp and the prop are drawn by the client
exports.qbx_core:CreateUseableItem('mining_helmet', function(source)
    local src = source
    if not util.player(src) then return false end

    local state = Player(src).state
    state:set('miningHelmet', not state.miningHelmet, true)

    return false
end)

exports.qbx_core:CreateUseableItem('mining_license', function(source, item)
    local src = source
    local metadata = type(item) == 'table' and item.metadata or {}
    if type(metadata.expires) ~= 'number' then return false end

    local key = metadata.expires > os.time() and 'licence_shown' or 'licence_shown_expired'
    util.notify(src, key, 'inform', metadata.holder or '?', os.date('%Y-%m-%d %H:%M', metadata.expires))

    return false
end)

-- The client asks to take the helmet off when it no longer carries one
RegisterNetEvent('city_mining:server:helmetGone', function()
    local src = source
    if util.count(src, 'mining_helmet') == 0 then Player(src).state:set('miningHelmet', false, true) end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then profiles.forget(player.PlayerData.citizenid) end
    if src then Player(src).state:set('miningHelmet', false, true) end
end)

AddEventHandler('playerDropped', function()
    local player = exports.qbx_core:GetPlayer(source)
    if player then profiles.forget(player.PlayerData.citizenid) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    profiles.flush()
    veins.clear()
    GlobalState.miningAreas = nil
end)
