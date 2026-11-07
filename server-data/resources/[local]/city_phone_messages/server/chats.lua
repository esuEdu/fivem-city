-- Reading and writing chats: the list, a chat's messages, sending, read receipts and reactions. Every action checks
-- that the player is a member of the chat; the sender is always the player's own number.
local common = require 'server.common'
local store = require 'server.store'

local chats = {}

local REACTIONS = {}
for _, name in ipairs(Config.Reactions) do REACTIONS[name] = true end

---Sends a message from a number to a chat and delivers it to everyone online in it
---@return table message
function chats.post(conversationId, sender, kind, body)
    local message = store.addMessage(conversationId, sender, kind, body)

    for _, member in ipairs(store.members(conversationId)) do
        local src = common.online(member.number)

        if src then
            TriggerClientEvent('city_phone_messages:client:message', src, message)

            -- Reaching an online phone counts as delivered
            if member.number ~= sender then store.delivered(conversationId, member.number, message.id) end
        end
    end

    return message
end

lib.callback.register('city_phone_messages:list', function(source)
    local src = source
    local _, number = common.player(src)
    if not number or common.throttled(src, 'list', 300) then return end

    store.markDelivered(number)

    local list = store.list(number)
    for i = 1, #list do
        list[i].is_group = list[i].is_group == true or list[i].is_group == 1
        local members = store.members(list[i].id)
        list[i].members = {}
        for j = 1, #members do list[i].members[j] = members[j].number end
    end

    return { number = number, conversations = list }
end)

-- Opening a chat: its messages, its members (with how far each has read) and the owner
lib.callback.register('city_phone_messages:open', function(source, conversationId, before)
    local src = source
    local number = common.member(src, conversationId)
    if not number then return end

    local conversation = store.conversation(conversationId)
    local messages = store.messages(conversationId, math.tointeger(before))

    return {
        id = conversation.id,
        name = conversation.name,
        owner = conversation.owner,
        group = conversation.is_group == true or conversation.is_group == 1,
        members = store.members(conversationId),
        messages = messages,
    }
end)

-- The 1:1 chat with a number (made the first time)
lib.callback.register('city_phone_messages:startDirect', function(source, target)
    local src = source
    local _, number = common.player(src)
    target = common.number(target)

    if not number or not target or common.throttled(src, 'start', 500) then return false, 'invalid' end
    if target == number then return false, 'self' end

    local id = store.direct(number, target)
    if id then return id end

    if not store.numberExists(target) then return false, 'unknown_number' end

    return store.create({ number, target }, false, nil, nil)
end)

lib.callback.register('city_phone_messages:send', function(source, conversationId, text)
    local src = source
    local number = common.member(src, conversationId)
    text = common.text(text, Config.MaxLength)

    if not number or not text or not common.hasPhone(src) then return false end
    if common.throttled(src, 'send', 400) then return false, 'slow' end

    return chats.post(conversationId, number, 'text', text) ~= nil
end)

-- A fixed location: where the player is now, read on the server
lib.callback.register('city_phone_messages:sendLocation', function(source, conversationId)
    local src = source
    local number = common.member(src, conversationId)
    if not number or not common.hasPhone(src) or common.throttled(src, 'send', 1000) then return false end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local body = json.encode({ x = math.floor(coords.x * 10) / 10, y = math.floor(coords.y * 10) / 10 })

    return chats.post(conversationId, number, 'location', body) ~= nil
end)

-- Read receipts: the chat is open on this phone up to that message
lib.callback.register('city_phone_messages:read', function(source, conversationId, upTo)
    local src = source
    local number = common.member(src, conversationId)
    upTo = math.tointeger(upTo)
    if not number or not upTo or common.throttled(src, 'read', 300) then return false end

    store.markRead(conversationId, number, upTo)
    common.toMembers(conversationId, 'city_phone_messages:client:read', number, conversationId, number, upTo)

    return true
end)

lib.callback.register('city_phone_messages:react', function(source, messageId, reaction)
    local src = source
    messageId = math.tointeger(messageId)
    if not messageId or (reaction ~= nil and not REACTIONS[reaction]) or common.throttled(src, 'react', 300) then return false end

    local message = store.message(messageId)
    local number = message and common.member(src, message.conversation_id)
    if not number or message.kind == 'system' then return false end

    store.setReaction(messageId, number, reaction)
    common.toMembers(message.conversation_id, 'city_phone_messages:client:reaction', nil, message.conversation_id, messageId, number, reaction)

    return true
end)

return chats
