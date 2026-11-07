-- Adds Market to city_phone and passes its page's requests to the server
local APP = 'market'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Market',
        labels = { ['pt-br'] = 'Market' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #ffb340, #ff9500)',
        page = 'web/index.html',
        order = 21,
    })
end

-- city_phone may start after us, or restart
CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

-- page callback -> server callback, with the same arguments
local FORWARD = {
    list = { 'category', 'search', 'before' },
    mine = {},
    favorites = {},
    photo = { 'id' },
    myPhotos = {},
    myPhoto = { 'id' },
    publish = { 'ad', 'photo' },
    edit = { 'id', 'ad', 'photo' },
    renew = { 'id' },
    delete = { 'id' },
    staffRemove = { 'id' },
    favorite = { 'id', 'favorite' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_market:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end

-- "Contact": opens the chat with the seller in Messages (if it is installed)
RegisterNUICallback('contact', function(data, cb)
    local number = lib.callback.await('city_phone_market:contact', false, type(data) == 'table' and data.id or nil)
    if number then TriggerEvent('city_phone_messages:client:openWith', number) end
    cb({ ok = number ~= nil })
end)
