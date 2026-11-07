-- Adds Weather to city_phone; the page asks for the forecast and the game hour (for day or night)
local function register()
    exports.city_phone:RegisterApp({
        id = 'weather',
        label = 'Weather',
        labels = { ['pt-br'] = 'Tempo' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #3a8dde, #66b8f0)',
        page = 'web/index.html',
        order = 23,
    })
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

RegisterNUICallback('get', function(_, cb)
    local data = lib.callback.await('city_phone_weather:get', false)
    if data then data.hour = GetClockHours() end
    cb({ ok = data ~= nil, result = data })
end)
