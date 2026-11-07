-- Adds Camera to city_phone. Its page has one big button that starts camera mode (client/camera.lua).
local camera = require 'client.camera'

local APP = 'camera'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Camera',
        labels = { ['pt-br'] = 'Câmera' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #8e8e93, #48484a)',
        page = 'web/index.html',
        order = 10,
    })
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

RegisterNUICallback('start', function(_, cb)
    cb({ ok = true })
    CreateThread(camera.start)
end)
