-- Adds Calendar to city_phone: a month view of the real date, all in the page
local function register()
    exports.city_phone:RegisterApp({
        id = 'calendar',
        label = 'Calendar',
        labels = { ['pt-br'] = 'Calendário' },
        icon = 'web/icon.svg',
        color = '#ffffff',
        page = 'web/index.html',
        order = 22,
    })
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)
