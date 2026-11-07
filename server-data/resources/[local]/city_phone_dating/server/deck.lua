-- The cards (profiles that want each other's gender, not swiped yet), like or pass, and matches
local common = require 'server.common'

-- gender 0 = man, 1 = woman (qbx charinfo)
local WANTS = { men = { 0 }, women = { 1 }, everyone = { 0, 1 } }
local INTEREST_IN = { [0] = { 'men', 'everyone' }, [1] = { 'women', 'everyone' } }

lib.callback.register('city_phone_dating:deck', function(source)
    local src = source
    local me = common.profile(src)
    if not me or common.throttled(src, 'deck', 500) then return end

    local wants = WANTS[me.interest] or WANTS.everyone
    local theirInterest = INTEREST_IN[me.gender] or INTEREST_IN[0]

    local rows = MySQL.query.await(([[
        SELECT p.`id`, p.`name`, p.`bio`, p.`age`,
            (SELECT GROUP_CONCAT(ph.`slot` ORDER BY ph.`slot`) FROM `phone_dating_photos` ph WHERE ph.`profile_id` = p.`id`) AS `slots`
        FROM `phone_dating_profiles` p
        WHERE p.`id` <> ? AND p.`gender` IN (%s) AND p.`interest` IN (?, ?)
            AND NOT EXISTS (SELECT 1 FROM `phone_dating_swipes` s WHERE s.`from_id` = ? AND s.`to_id` = p.`id`)
            AND EXISTS (SELECT 1 FROM `phone_dating_photos` ph WHERE ph.`profile_id` = p.`id`)
        ORDER BY RAND() LIMIT ?
    ]]):format(#wants == 2 and '?, ?' or '?'), (function()
        local params = { me.id }
        for _, gender in ipairs(wants) do params[#params + 1] = gender end
        params[#params + 1] = theirInterest[1]
        params[#params + 1] = theirInterest[2]
        params[#params + 1] = me.id
        params[#params + 1] = Config.DeckSize
        return params
    end)()) or {}

    for _, row in ipairs(rows) do
        local photos = {}
        for slot in tostring(row.slots or ''):gmatch('%d+') do photos[#photos + 1] = tonumber(slot) end
        row.photos, row.slots = photos, nil
    end

    return rows
end)

---@param a integer
---@param b integer
---@return integer low, integer high
local function pair(a, b)
    if a < b then return a, b end
    return b, a
end

-- Returns { match = true, name } when both liked each other
lib.callback.register('city_phone_dating:swipe', function(source, targetId, liked)
    local src = source
    local me = common.profile(src)
    targetId = common.int(targetId)
    if not me or not targetId or targetId == me.id or common.throttled(src, 'swipe', 250) then return false end

    local target = MySQL.single.await('SELECT `id`, `citizenid`, `name` FROM `phone_dating_profiles` WHERE `id` = ?', { targetId })
    if not target then return false end

    MySQL.insert.await('INSERT IGNORE INTO `phone_dating_swipes` (`from_id`, `to_id`, `liked`, `created_at`) VALUES (?, ?, ?, ?)', {
        me.id, targetId, liked == true and 1 or 0, os.time(),
    })

    if liked ~= true then return { match = false } end

    local likedBack = MySQL.scalar.await('SELECT 1 FROM `phone_dating_swipes` WHERE `from_id` = ? AND `to_id` = ? AND `liked` = 1', { targetId, me.id })
    if not likedBack then return { match = false } end

    local a, b = pair(me.id, targetId)
    local now = os.time()
    local added = MySQL.update.await('INSERT IGNORE INTO `phone_dating_matches` (`a`, `b`, `created_at`, `last_at`) VALUES (?, ?, ?, ?)', { a, b, now, now })

    if added > 0 then
        local other = common.notify(target.citizenid, ("It's a match with %s!"):format(me.name))
        if other then TriggerClientEvent('city_phone_dating:client:refresh', other) end
    end

    return { match = true, name = target.name, id = target.id }
end)

-- Your matches, newest conversation first, with the last message
lib.callback.register('city_phone_dating:matches', function(source)
    local src = source
    local me = common.profile(src)
    if not me then return end

    return MySQL.query.await([[
        SELECT m.`id`, m.`last_at` AS `lastAt`, p.`id` AS `profileId`, p.`name`, p.`age`,
            (SELECT `text` FROM `phone_dating_messages` x WHERE x.`match_id` = m.`id` ORDER BY x.`id` DESC LIMIT 1) AS `last`
        FROM `phone_dating_matches` m
        JOIN `phone_dating_profiles` p ON p.`id` = IF(m.`a` = ?, m.`b`, m.`a`)
        WHERE m.`a` = ? OR m.`b` = ?
        ORDER BY m.`last_at` DESC
    ]], { me.id, me.id, me.id }) or {}
end)

-- Unmatching ends the chat for both; they don't see each other's card again
lib.callback.register('city_phone_dating:unmatch', function(source, matchId)
    local src = source
    local me = common.profile(src)
    matchId = common.int(matchId)
    if not me or not matchId then return false end

    local removed = MySQL.update.await('DELETE FROM `phone_dating_matches` WHERE `id` = ? AND (`a` = ? OR `b` = ?)', { matchId, me.id, me.id })
    if removed < 1 then return false end

    MySQL.update.await('DELETE FROM `phone_dating_messages` WHERE `match_id` = ?', { matchId })

    return true
end)
