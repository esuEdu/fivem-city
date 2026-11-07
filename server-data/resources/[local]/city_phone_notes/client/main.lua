-- Adds Notes to city_phone and passes its page's requests to the server
local function register()
    exports.city_phone:RegisterApp({
        id = 'notes',
        label = 'Notes',
        labels = { ['pt-br'] = 'Notas' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #ffffff, #f2f2f7)',
        page = 'web/index.html',
        order = 20,
    })
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

local FORWARD = {
    list = {},
    save = { 'note' },
    pin = { 'id', 'pinned' },
    delete = { 'id' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_notes:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end
