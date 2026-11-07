-- Adds Matchy to city_phone and passes its page's requests to the server
local APP = 'dating'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Matchy',
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #ff6a88, #ff2d55)',
        page = 'web/index.html',
        order = 23,
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
    me = {},
    save = { 'profile' },
    deleteProfile = {},
    photo = { 'profileId', 'slot' },
    myPhotos = {},
    myPhoto = { 'id' },
    deck = {},
    swipe = { 'id', 'liked' },
    matches = {},
    unmatch = { 'id' },
    messages = { 'id', 'before' },
    send = { 'id', 'text' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_dating:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end

-- A new match or message: the page reloads what it shows
RegisterNetEvent('city_phone_dating:client:refresh', function(matchId)
    if GetInvokingResource() then return end
    exports.city_phone:SendAppMessage(APP, { action = 'refresh', match = matchId })
end)
