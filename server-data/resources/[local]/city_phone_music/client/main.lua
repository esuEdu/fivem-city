-- Adds Music to city_phone and passes its page's requests to the server. The page itself plays the audio (YouTube's
-- player or an <audio>), so only this player hears it; the song playing shows in the dynamic island.
local APP = 'music'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Music',
        labels = { ['pt-br'] = 'Música' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #1ed760, #128c3f)',
        page = 'web/index.html',
        order = 25,
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
    library = {},
    addTrack = { 'kind', 'ref', 'title', 'artist' },
    removeTrack = { 'id' },
    createPlaylist = { 'name' },
    renamePlaylist = { 'id', 'name' },
    deletePlaylist = { 'id' },
    playlist = { 'id' },
    addToPlaylist = { 'playlist', 'track' },
    removeFromPlaylist = { 'playlist', 'track' },
    canSearch = {},
    search = { 'query' },
    lookup = { 'link' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_music:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end

-- The song playing, in the dynamic island (nil when nothing plays)
RegisterNUICallback('nowPlaying', function(data, cb)
    if type(data) == 'table' and type(data.title) == 'string' then
        exports.city_phone:SetActivity(APP, {
            icon = 'music',
            color = '#1ed760',
            text = data.title:sub(1, 60),
            detail = type(data.artist) == 'string' and data.artist:sub(1, 60) or nil,
        })
    else
        exports.city_phone:SetActivity(APP, nil)
    end

    cb(true)
end)

-- Closing the app from the app switcher stops the music
AddEventHandler('city_phone:client:appClosed', function(id)
    if id == APP then exports.city_phone:SetActivity(APP, nil) end
end)
