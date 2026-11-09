-- The other officers on duty on the map (server/unitblips.lua sends where they are): a blue arrow on foot, a car
-- icon in a vehicle, with their callsign. Gone when this officer goes off duty.

local job = require 'client.job'

local STYLE = Config.UnitBlips

---@type table<integer, integer> server id -> blip
local blips = {}

local function clear()
    for id, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[id] = nil
    end
end

RegisterNetEvent('city_police:client:unitBlips', function(list)
    if GetInvokingResource() or type(list) ~= 'table' or not job.onDuty() then return clear() end

    local seen = {}
    local me = cache.serverId

    for _, unit in ipairs(list) do
        if unit.id ~= me then
            seen[unit.id] = true

            local blip = blips[unit.id]
            if not blip then
                blip = AddBlipForCoord(unit.x, unit.y, 0.0)
                SetBlipColour(blip, STYLE.colour)
                SetBlipScale(blip, STYLE.scale)
                SetBlipAsShortRange(blip, false)
                SetBlipCategory(blip, 7)
                ShowHeadingIndicatorOnBlip(blip, true)
                blips[unit.id] = blip
            end

            SetBlipCoords(blip, unit.x, unit.y, 0.0)
            SetBlipSprite(blip, unit.car and STYLE.carSprite or STYLE.sprite)
            SetBlipColour(blip, STYLE.colour)
            SetBlipRotation(blip, math.floor(unit.h))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(unit.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    for id, blip in pairs(blips) do
        if not seen[id] then
            RemoveBlip(blip)
            blips[id] = nil
        end
    end
end)

AddEventHandler('city_police:client:dutyChanged', function(onDuty)
    if not onDuty then clear() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then clear() end
end)
