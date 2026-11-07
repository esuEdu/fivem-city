-- Shared by the server files: who a player is (by phone number), reaching members who are online, checks
local store = require 'server.store'

local common = {}

local last = {}

---@return table? player
---@return string? number
function common.player(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- The number of the phone in use: their own, or a burner's (city_phone decides)
    return player, exports.city_phone:ActiveNumber(src)
end

---@param number string
---@return integer? source of the player whose phone answers that number now
function common.online(number)
    return exports.city_phone:SourceByNumber(number)
end

---@param value unknown
---@return string?
function common.number(value)
    if type(value) ~= 'string' and type(value) ~= 'number' then return end

    local digits = tostring(value):gsub('%D', '')
    if #digits < Config.NumberLength.min or #digits > Config.NumberLength.max then return end

    return digits
end

---Text a player typed: trimmed, no control characters, within the limit
---@return string?
function common.text(value, limit)
    if type(value) ~= 'string' then return end

    local text = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    if #text < 1 then return end

    return text:sub(1, limit)
end

function common.hasPhone(src)
    return exports.city_phone:HasPhone(src)
end

function common.throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

---The player's number, if they are in the chat
---@return string? number
---@return table? player
function common.member(src, conversationId)
    local player, number = common.player(src)
    if not player or type(conversationId) ~= 'number' then return end
    if not store.isMember(conversationId, number) then return end

    return number, player
end

---Sends an event to every member of a chat who is online
---@param conversationId integer
---@param event string
---@param except? string a number to skip
function common.toMembers(conversationId, event, except, ...)
    for _, member in ipairs(store.members(conversationId)) do
        if member.number ~= except then
            local src = common.online(member.number)
            if src then TriggerClientEvent(event, src, ...) end
        end
    end
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
