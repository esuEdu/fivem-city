-- Warnings (city_staff_warnings), kicks, and bans in qbx_core's `bans` table, which qbx_core checks on connect.

local rules = require 'shared.rules'
local staff = require 'server.staff'

local REASON_LENGTH = 200

staff.register('warn', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    local text = rules.cleanText(data.reason, REASON_LENGTH)
    if not text then return false, 'no_reason' end

    local who, by = staff.who(target), staff.who(src)

    MySQL.insert.await('INSERT INTO `city_staff_warnings` (`citizenid`, `license`, `reason`, `staff_name`) VALUES (?, ?, ?, ?)', {
        who.citizenid, who.license, text, by.name:sub(1, 100),
    })

    TriggerClientEvent('city_staff:client:warned', target, text)
    staff.log(src, 'warn', target, text)

    return true
end)

staff.register('kick', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    local text = rules.cleanText(data.reason, REASON_LENGTH)
    if not text then return false, 'no_reason' end

    -- Logged first: the target's name is gone once they're dropped
    staff.log(src, 'kick', target, text)
    DropPlayer(tostring(target), locale('kick_message', text))

    return true
end)

staff.register('ban', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    local text = rules.cleanText(data.reason, REASON_LENGTH)
    if not text then return false, 'no_reason' end

    local seconds, why = rules.banSeconds(data.hours, staff.can(src, 'banLong'))
    if not seconds then return false, why end

    local id = tostring(target)
    local expire = seconds == 0 and rules.PERMANENT or os.time() + seconds
    local license = GetPlayerIdentifierByType(id, 'license2') or GetPlayerIdentifierByType(id, 'license')

    MySQL.insert.await('INSERT INTO `bans` (`name`, `license`, `discord`, `ip`, `reason`, `expire`, `bannedby`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        (GetPlayerName(id) or ''):sub(1, 50), license, GetPlayerIdentifierByType(id, 'discord'), GetPlayerIdentifierByType(id, 'ip'),
        text, expire, staff.who(src).name:sub(1, 255),
    })

    local length = seconds == 0 and locale('permanent') or locale('hours', math.floor(seconds / 3600))
    staff.log(src, 'ban', target, ('%s: %s'):format(length, text))

    local untilText = seconds == 0 and locale('permanent') or os.date('%Y-%m-%d %H:%M', expire)
    DropPlayer(id, locale('ban_message', text, untilText))

    return true
end)

-- Active bans, newest first. IPs stay on the server.
staff.register('bans', function()
    local rows = MySQL.query.await('SELECT `id`, `name`, `license`, `reason`, `expire`, `bannedby` FROM `bans` WHERE `expire` > ? ORDER BY `id` DESC LIMIT 200', { os.time() }) or {}

    for _, ban in ipairs(rows) do
        ban.permanent = ban.expire >= rules.PERMANENT
    end

    return true, rows
end, 'ban')

staff.register('unban', function(src, data)
    local id = rules.toId(data.id)
    if not id then return false, 'invalid' end

    local ban = MySQL.single.await('SELECT `name`, `reason` FROM `bans` WHERE `id` = ?', { id })
    if not ban then return false, 'not_found' end

    MySQL.query.await('DELETE FROM `bans` WHERE `id` = ?', { id })
    staff.log(src, 'unban', { name = ban.name }, ban.reason)

    return true
end)
