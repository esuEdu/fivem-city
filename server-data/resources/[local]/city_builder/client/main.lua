-- Loads the placed world from the server and keeps it in step with what staff change.
local world = require 'client.world'

local function fetchWorld()
    while not NetworkIsSessionStarted() do Wait(500) end

    for _ = 1, 30 do
        local snapshot = lib.callback.await('city_builder:world', false)

        if snapshot then
            world.load(snapshot)
            return
        end

        Wait(2000)
    end

    lib.print.warn('city_builder: could not load the placed props')
end

CreateThread(fetchWorld)

RegisterNetEvent('city_builder:client:world', function(snapshot)
    if type(snapshot) == 'table' then world.load(snapshot) end
end)

RegisterNetEvent('city_builder:client:props', function(props)
    world.set(props)
    TriggerEvent('city_builder:client:changed')
end)

RegisterNetEvent('city_builder:client:removeProps', function(ids)
    world.remove(ids)
    TriggerEvent('city_builder:client:changed')
end)

RegisterNetEvent('city_builder:client:groups', function(groups)
    world.setGroups(groups)
    TriggerEvent('city_builder:client:changed')
end)

RegisterNetEvent('city_builder:client:removeGroup', function(id)
    world.removeGroup(id)
    TriggerEvent('city_builder:client:changed')
end)

RegisterNetEvent('city_builder:client:hide', function(hide)
    world.hide(hide)
    TriggerEvent('city_builder:client:changed')
end)

RegisterNetEvent('city_builder:client:unhide', function(id)
    world.unhide(id)
    TriggerEvent('city_builder:client:changed')
end)
