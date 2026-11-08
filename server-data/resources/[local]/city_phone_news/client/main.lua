-- Adds Weazel News to city_phone and passes its page's requests to the server
local APP = 'news'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Weazel News',
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #e53935, #b71c1c)',
        page = 'web/index.html',
        order = 24,
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
    list = { 'category', 'before' },
    article = { 'id' },
    publish = { 'article' },
    edit = { 'id', 'article' },
    delete = { 'id' },
    like = { 'id', 'liked' },
    comments = { 'id', 'before' },
    comment = { 'id', 'text' },
    deleteComment = { 'id' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_news:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end
