-- Adds InstaPic to city_phone and passes its page's requests to the server
local APP = 'social'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'InstaPic',
        icon = 'web/icon.svg',
        color = 'linear-gradient(45deg, #feda75, #fa7e1e 30%, #d62976 60%, #962fbf 85%, #4f5bd5)',
        page = 'web/index.html',
        order = 22,
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
    createAccount = { 'username', 'name' },
    editProfile = { 'name', 'bio', 'avatar' },
    avatar = { 'username' },
    profile = { 'username' },
    search = { 'query' },
    posts = { 'scope', 'username', 'before' },
    image = { 'id' },
    stories = {},
    publish = { 'kind', 'photo', 'caption' },
    deletePost = { 'id' },
    like = { 'id', 'liked' },
    comments = { 'id', 'before' },
    comment = { 'id', 'text' },
    deleteComment = { 'id' },
    follow = { 'username', 'follow' },
    myPhotos = {},
    myPhoto = { 'id' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_social:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end
