-- Live location: for Config.LiveMinutes the chat's other members see a moving point on their map. The position is
-- read on the server every few seconds; the sender can stop it early, and it stops if they leave or lose the phone.
local chats = require 'server.chats'
local common = require 'server.common'
local store = require 'server.store'

---@type table<integer, { src: integer, number: string, conversation: integer, ends: integer, members: string[] }>
local sessions = {}
local nextSession = 0

-- The chat's other members are read once when sharing starts, not on every update
local function send(session, ...)
    for _, number in ipairs(session.members) do
        local src = common.online(number)
        if src then TriggerClientEvent('city_phone_messages:client:live', src, ...) end
    end
end

local function stop(id)
    local session = sessions[id]
    if not session then return end

    sessions[id] = nil
    send(session, id, nil)
    TriggerClientEvent('city_phone_messages:client:live', session.src, id, nil)
end

lib.callback.register('city_phone_messages:startLive', function(source, conversationId)
    local src = source
    local number = common.member(src, conversationId)
    if not number or not common.hasPhone(src) or common.throttled(src, 'live', 3000) then return false end

    -- One live share per chat per player
    for id, session in pairs(sessions) do
        if session.src == src and session.conversation == conversationId then stop(id) end
    end

    nextSession = nextSession + 1

    local ends = os.time() + Config.LiveMinutes * 60
    local members = {}
    for _, member in ipairs(store.members(conversationId)) do
        if member.number ~= number then members[#members + 1] = member.number end
    end

    sessions[nextSession] = { src = src, number = number, conversation = conversationId, ends = ends, members = members }

    chats.post(conversationId, number, 'live', json.encode({ session = nextSession, ends = ends }))

    return true
end)

lib.callback.register('city_phone_messages:stopLive', function(source, sessionId)
    local session = sessions[tonumber(sessionId) or 0]
    if session and session.src == source then stop(tonumber(sessionId)) end
    return true
end)

CreateThread(function()
    while true do
        Wait(Config.LiveUpdateSeconds * 1000)

        local now = os.time()

        for id, session in pairs(sessions) do
            if now >= session.ends or not GetPlayerName(session.src) or not common.hasPhone(session.src) then
                stop(id)
            else
                local coords = GetEntityCoords(GetPlayerPed(session.src))
                send(session, id, { x = coords.x, y = coords.y, z = coords.z, number = session.number, ends = session.ends })
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    for id, session in pairs(sessions) do
        if session.src == src then stop(id) end
    end
end)
