-- Adds Photos to city_phone and passes its page's requests to the server
local APP = 'photos'

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Photos',
        labels = { ['pt-br'] = 'Fotos' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #ffffff, #e9e9ee)',
        page = 'web/index.html',
        order = 11,
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
    photo = { 'id' },
    favorite = { 'id', 'favorite' },
    delete = { 'id' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result = lib.callback.await(('city_phone_photos:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result })
    end)
end

RegisterNUICallback('wallpaper', function(data, cb)
    local id = math.tointeger(tonumber(data.id))
    cb({ ok = id ~= nil and exports.city_phone:SetWallpaperPhoto(id) == true })
end)

-- The Camera app saved a new photo: the library refreshes if it is open
AddEventHandler('city_phone_photos:client:added', function()
    exports.city_phone:SendAppMessage(APP, { action = 'refresh' })
end)
