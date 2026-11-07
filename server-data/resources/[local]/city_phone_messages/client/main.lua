-- Adds Messages to city_phone, passes the page's requests to the server, and handles new messages: a notification
-- (unless that chat is open on screen), the unread badge, and live updates for the page.
local texts = require 'shared.texts'

local APP = 'messages'

local viewing = nil -- chat open on the page right now
local unread = 0

local function t(key)
    local settings = exports.city_phone:GetSettings() or {}
    local list = texts[settings.language] or texts.en
    return list[key] or texts.en[key] or key
end

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Messages',
        labels = { ['pt-br'] = 'Mensagens' },
        icon = 'web/icon.svg',
        color = '#30d158',
        page = 'web/index.html',
        dock = true,
        order = 2,
    })
    exports.city_phone:SetBadge(APP, unread)
end

local function refreshBadge()
    local data = lib.callback.await('city_phone_messages:list', false)
    if not data then return end

    unread = 0
    for _, conversation in ipairs(data.conversations) do unread = unread + (tonumber(conversation.unread) or 0) end
    exports.city_phone:SetBadge(APP, unread)
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
    if LocalPlayer.state.isLoggedIn then refreshBadge() end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(3000, refreshBadge)
end)

-- page callback -> server callback, with the same arguments
local FORWARD = {
    list = {},
    open = { 'id', 'before' },
    startDirect = { 'number' },
    send = { 'id', 'text' },
    sendLocation = { 'id' },
    startLive = { 'id' },
    stopLive = { 'session' },
    read = { 'id', 'upTo' },
    react = { 'message', 'reaction' },
    createGroup = { 'name', 'numbers' },
    addMember = { 'id', 'number' },
    removeMember = { 'id', 'number' },
    rename = { 'id', 'name' },
    leave = { 'id' },
    contacts = {},
}

for name, keys in pairs(FORWARD) do
    RegisterNUICallback(name, function(data, cb)
        local args = {}
        for i, key in ipairs(keys) do args[i] = type(data) == 'table' and data[key] or nil end

        local result, reason = lib.callback.await(('city_phone_messages:%s'):format(name), false, table.unpack(args, 1, #keys))
        cb({ ok = result ~= false and result ~= nil, result = result, reason = reason })

        -- Reading or leaving changes the unread count
        if name == 'read' or name == 'leave' then CreateThread(refreshBadge) end
    end)
end

-- Sending the route set on the map as a location; the server checks the point
RegisterNUICallback('sendRoute', function(data, cb)
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return cb({ ok = false, reason = 'no_route' }) end

    local coords = GetBlipInfoIdCoord(blip)
    local id = type(data) == 'table' and data.id or nil
    local result = lib.callback.await('city_phone_messages:sendRoute', false, id, coords.x + 0.0, coords.y + 0.0)
    cb({ ok = result == true })
end)

-- The page says which chat is on screen, so a new message there doesn't notify
RegisterNUICallback('viewing', function(data, cb)
    viewing = tonumber(data.id)
    cb({ ok = true })
end)

-- A location in a chat: put it on the GPS
RegisterNUICallback('waypoint', function(data, cb)
    local x, y = tonumber(data.x), tonumber(data.y)
    if x and y then SetNewWaypoint(x, y) end
    cb({ ok = x ~= nil })
end)

RegisterNetEvent('city_phone_messages:client:message', function(message)
    if GetInvokingResource() or type(message) ~= 'table' then return end

    exports.city_phone:SendAppMessage(APP, { action = 'message', message = message })

    local mine = message.sender == (LocalPlayer.state.phoneBurner or tostring(QBX.PlayerData.charinfo.phone or ''))
    if mine or message.kind == 'system' then return end

    -- On screen the page marks it read; otherwise a notification and one more unread
    if viewing == message.conversation and exports.city_phone:IsOpen() then return end

    local text = message.kind == 'text' and message.body or t(message.kind == 'live' and 'live' or 'location')
    exports.city_phone:Notify({ app = 'messages', title = t('new'), text = text })

    unread = unread + 1
    exports.city_phone:SetBadge(APP, unread)
end)

RegisterNetEvent('city_phone_messages:client:read', function(conversation, number, upTo)
    if GetInvokingResource() then return end
    exports.city_phone:SendAppMessage(APP, { action = 'read', conversation = conversation, number = number, upTo = upTo })
end)

RegisterNetEvent('city_phone_messages:client:reaction', function(conversation, message, number, reaction)
    if GetInvokingResource() then return end
    exports.city_phone:SendAppMessage(APP, { action = 'reaction', conversation = conversation, message = message, number = number, reaction = reaction })
end)

RegisterNetEvent('city_phone_messages:client:left', function(conversation)
    if GetInvokingResource() then return end
    exports.city_phone:SendAppMessage(APP, { action = 'left', conversation = conversation })
end)

-- "Message" on a contact in the Phone app
AddEventHandler('city_phone_messages:client:openWith', function(number)
    exports.city_phone:OpenApp(APP)
    exports.city_phone:SendAppMessage(APP, { action = 'openWith', number = number })
end)
