-- The control center flashlight: a light cast forward from the player while it is on, even with the phone closed.
-- Only this player sees it.
local on = false

local function loop()
    local light = Config.Flashlight

    while on do
        local from = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.3, 0.5)
        local forward = GetEntityForwardVector(cache.ped)

        DrawSpotLight(from.x, from.y, from.z, forward.x, forward.y, forward.z - 0.15, 255, 255, 235,
            light.distance, light.brightness, 0.0, light.radius, light.falloff)

        Wait(0)
    end
end

local function set(value)
    value = value == true
    if value == on then return end

    on = value
    if on then CreateThread(loop) end
end

RegisterNUICallback('flashlight', function(data, cb)
    set(data.on)
    cb(on)
end)

-- Losing the phone or going down turns it off
AddEventHandler('ox_inventory:itemCount', function(name, count)
    if name == Config.Item and count < 1 then
        set(false)
        SendNUIMessage({ action = 'flashlight', on = false })
    end
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value and on then
        set(false)
        SendNUIMessage({ action = 'flashlight', on = false })
    end
end)
