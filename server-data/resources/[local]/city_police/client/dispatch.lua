-- Officers' side of calls: a blip and a sound for each new call (the tablet shows the notification), removed when
-- the call closes or expires.

local blips = {}

---@param id integer
local function removeBlip(id)
    if blips[id] then RemoveBlip(blips[id]) end
    blips[id] = nil
end

RegisterNetEvent('city_police:client:newCall', function(call)
    if GetInvokingResource() or type(call) ~= 'table' then return end

    local style = call.kind == 'panic' and Config.Dispatch.panicBlip or Config.Dispatch.blip
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)

    SetBlipSprite(blip, style.sprite)
    SetBlipColour(blip, style.colour)
    SetBlipScale(blip, style.scale)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s · %s'):format(call.code, call.title))
    EndTextCommandSetBlipName(blip)

    removeBlip(call.id)
    blips[call.id] = blip

    SetTimeout(10000, function()
        if blips[call.id] then SetBlipFlashes(blips[call.id], false) end
    end)
    SetTimeout(Config.Dispatch.minutes * 60000, function() removeBlip(call.id) end)

    if call.priority == 2 then
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    else
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    end
end)

RegisterNetEvent('city_police:client:callClosed', function(id)
    if GetInvokingResource() then return end
    removeBlip(id)
end)

AddEventHandler('city_police:client:dutyChanged', function(onDuty)
    if onDuty then return end

    for id in pairs(blips) do removeBlip(id) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(blips) do removeBlip(id) end
end)
