-- Group chats: the creator names the group and adds or removes people; anyone can leave. Changes show up in the chat
-- as system messages.
local chats = require 'server.chats'
local common = require 'server.common'
local store = require 'server.store'

local function system(conversationId, actor, text)
    chats.post(conversationId, actor, 'system', text)
end

lib.callback.register('city_phone_messages:createGroup', function(source, name, numbers)
    local src = source
    local _, number = common.player(src)
    name = common.text(name, Config.GroupNameLength)

    if not number or not name or type(numbers) ~= 'table' or common.throttled(src, 'group', 2000) then return false, 'invalid' end

    local members, seen = { number }, { [number] = true }

    for _, value in ipairs(numbers) do
        local other = common.number(value)

        if other and not seen[other] then
            if #members >= Config.MaxGroup then return false, 'full' end
            if not store.numberExists(other) then return false, 'unknown_number' end

            seen[other] = true
            members[#members + 1] = other
        end
    end

    if #members < 2 then return false, 'invalid' end

    local id = store.create(members, true, name, number)
    system(id, number, json.encode({ event = 'created', by = number, name = name }))

    return id
end)

---@return string? number the caller's, when they own the group
local function owner(src, conversationId)
    local number = common.member(src, conversationId)
    local conversation = number and store.conversation(conversationId)

    if not conversation or not (conversation.is_group == true or conversation.is_group == 1) then return end
    if conversation.owner ~= number then return end

    return number
end

lib.callback.register('city_phone_messages:addMember', function(source, conversationId, target)
    local src = source
    local number = owner(src, conversationId)
    target = common.number(target)

    if not number or not target or common.throttled(src, 'group', 1000) then return false, 'invalid' end
    if #store.members(conversationId) >= Config.MaxGroup then return false, 'full' end
    if not store.numberExists(target) then return false, 'unknown_number' end

    store.addMember(conversationId, target)
    system(conversationId, number, json.encode({ event = 'added', by = number, who = target }))

    return true
end)

lib.callback.register('city_phone_messages:removeMember', function(source, conversationId, target)
    local src = source
    local number = owner(src, conversationId)
    target = common.number(target)

    if not number or not target or target == number or common.throttled(src, 'group', 1000) then return false end
    if not store.isMember(conversationId, target) then return false end

    system(conversationId, number, json.encode({ event = 'removed', by = number, who = target }))
    store.removeMember(conversationId, target)

    local removed = common.online(target)
    if removed then TriggerClientEvent('city_phone_messages:client:left', removed, conversationId) end

    return true
end)

lib.callback.register('city_phone_messages:rename', function(source, conversationId, name)
    local src = source
    local number = owner(src, conversationId)
    name = common.text(name, Config.GroupNameLength)

    if not number or not name or common.throttled(src, 'group', 1000) then return false end

    store.rename(conversationId, name)
    system(conversationId, number, json.encode({ event = 'renamed', by = number, name = name }))

    return true
end)

-- Leaving a group; the owner leaving hands it to the next member
lib.callback.register('city_phone_messages:leave', function(source, conversationId)
    local src = source
    local number = common.member(src, conversationId)
    local conversation = number and store.conversation(conversationId)

    if not conversation or not (conversation.is_group == true or conversation.is_group == 1) then return false end

    system(conversationId, number, json.encode({ event = 'left', by = number }))
    store.removeMember(conversationId, number)

    if conversation.owner == number then
        local next = store.members(conversationId)[1]
        if next then store.setOwner(conversationId, next.number) end
    end

    return true
end)
