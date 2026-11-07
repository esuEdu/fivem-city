-- Adds the Phone app to city_phone and passes its page's requests to the server. The page runs inside the phone and
-- calls these with fetch('https://city_phone_calls/<name>').
local APP = 'phone'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Phone',
        labels = { ['pt-br'] = 'Telefone' },
        icon = 'web/icon.svg',
        color = '#34c759',
        page = 'web/index.html',
        dock = true,
        order = 1,
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
    data = {},
    saveContact = { 'contact' },
    deleteContact = { 'id' },
    block = { 'number', 'blocked' },
    clearRecents = {},
    dial = { 'number', 'hidden' },
    add = { 'number' },
    accept = {},
    hangup = {},
    nearby = {},
    share = { 'target' },
    services = {},
    report = { 'service', 'kind', 'text', 'anonymous' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_calls:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end

-- "Message" on a contact: opens that chat in the Messages app (if it is installed)
RegisterNUICallback('message', function(data, cb)
    if type(data.number) == 'string' then TriggerEvent('city_phone_messages:client:openWith', data.number) end
    cb({ ok = true })
end)
