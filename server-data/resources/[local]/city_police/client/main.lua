-- Station blips, and the duty change the server confirms.
lib.locale()

local job = require 'client.job'

local blips = {}

for _, station in ipairs(Config.Stations) do
    local blip = AddBlipForCoord(station.blip.x, station.blip.y, station.blip.z)

    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.colour)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(station.label)
    EndTextCommandSetBlipName(blip)

    blips[#blips + 1] = blip
end

RegisterNetEvent('city_police:client:duty', function(onDuty)
    if GetInvokingResource() then return end

    TriggerEvent('city_police:client:dutyChanged', onDuty == true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)

-- Other scripts may ask: exports.city_police:IsOnDuty()
exports('IsOnDuty', job.onDuty)
