-- Puts DarkChat on the phone only while the encrypted USB is carried, and passes its page's requests to the server
local APP = 'darkchat'

local shown = false
local viewing = nil

local function hasUsb()
    return exports.city_inventory:GetItemCount(Config.Item) > 0
end

local function update()
    if GetResourceState('city_phone') ~= 'started' then return end

    local carry = hasUsb()
    if carry == shown then return end

    shown = carry

    if carry then
        exports.city_phone:RegisterApp({
            id = APP,
            label = 'DarkChat',
            icon = 'web/icon.svg',
            color = 'linear-gradient(180deg, #1c1c1e, #000000)',
            page = 'web/index.html',
            order = 40,
        })
    else
        viewing = nil
        exports.city_phone:RemoveApp(APP)
    end
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    update()
end)

-- city_phone restarted: it forgot the app
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'city_phone' then return end
    shown = false
    update()
end)

AddEventHandler('ox_inventory:itemCount', function(name)
    if name == Config.Item then update() end
end)

-- A new character may not carry it
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2000, update)
end)

-- page callback -> server callback, with the same arguments
local FORWARD = {
    me = {},
    setAlias = { 'alias' },
    enter = { 'name', 'password' },
    leave = { 'id' },
    messages = { 'id', 'before' },
    send = { 'id', 'text' },
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_darkchat:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })
    end)
end

-- The page says which room is on screen, so a message there doesn't notify
RegisterNUICallback('viewing', function(data, cb)
    viewing = type(data) == 'table' and tonumber(data.id) or nil
    cb({ ok = true })
end)

AddEventHandler('city_phone:client:appClosed', function(id)
    if id == APP then viewing = nil end
end)

RegisterNetEvent('city_phone_darkchat:client:message', function(roomId)
    if GetInvokingResource() or not shown then return end

    exports.city_phone:SendAppMessage(APP, { action = 'message', room = roomId })

    if viewing ~= roomId or not exports.city_phone:IsOpen() then
        exports.city_phone:Notify({ app = APP, title = 'DarkChat', text = 'New encrypted message' })
    end
end)
