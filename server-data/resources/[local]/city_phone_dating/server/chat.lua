-- The private chat of a match: messages only between the two, never their numbers
local common = require 'server.common'

local lastMessage = {}

---The match if the caller is in it, and the other person's profile id
---@return table? match, integer? otherId
local function matchOf(me, matchId)
    matchId = common.int(matchId)
    if not matchId then return end

    local match = MySQL.single.await('SELECT `id`, `a`, `b` FROM `phone_dating_matches` WHERE `id` = ? AND (`a` = ? OR `b` = ?)', { matchId, me.id, me.id })
    if not match then return end

    return match, match.a == me.id and match.b or match.a
end

lib.callback.register('city_phone_dating:messages', function(source, matchId, before)
    local src = source
    local me = common.profile(src)
    if not me then return end

    local match = matchOf(me, matchId)
    if not match then return end

    local sql = 'SELECT `id`, `text`, `created_at` AS `createdAt`, `sender` = ? AS `mine` FROM `phone_dating_messages` WHERE `match_id` = ?'
    local params = { me.id, match.id }

    before = common.int(before)
    if before then
        sql = sql .. ' AND `id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.PageSize

    local rows = MySQL.query.await(sql .. ' ORDER BY `id` DESC LIMIT ?', params) or {}
    for _, row in ipairs(rows) do row.mine = row.mine == 1 or row.mine == true end

    return rows
end)

lib.callback.register('city_phone_dating:send', function(source, matchId, text)
    local src = source
    local me = common.profile(src)
    text = common.text(text, Config.MessageLength, true)
    if not me or not text or text == '' or not common.hasPhone(src) then return false end

    local now = GetGameTimer()
    if lastMessage[src] and now - lastMessage[src] < Config.MessageCooldown * 1000 then return false, 'slow' end

    local match, otherId = matchOf(me, matchId)
    if not match then return false end

    lastMessage[src] = now

    MySQL.insert.await('INSERT INTO `phone_dating_messages` (`match_id`, `sender`, `text`, `created_at`) VALUES (?, ?, ?, ?)', {
        match.id, me.id, text, os.time(),
    })
    MySQL.update('UPDATE `phone_dating_matches` SET `last_at` = ? WHERE `id` = ?', { os.time(), match.id })

    local other = MySQL.scalar.await('SELECT `citizenid` FROM `phone_dating_profiles` WHERE `id` = ?', { otherId })
    local otherSrc = other and common.notify(other, ('%s: %s'):format(me.name, text:sub(1, 80)))
    if otherSrc then TriggerClientEvent('city_phone_dating:client:refresh', otherSrc, match.id) end

    return true
end)

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
end)
