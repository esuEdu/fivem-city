-- Numbers the Dashboard, Ratings and Team tabs share, worked out from city_staff_reports and city_staff_log.

local rules = require 'shared.rules'
local staff = require 'server.staff'

local metrics = {}

---@param value unknown
---@return number?
function metrics.round1(value)
    value = tonumber(value)
    return value and math.floor(value * 10 + 0.5) / 10 or nil
end

---Staff on the server right now, by license.
---@return table<string, { level: string, name: string }>
function metrics.onlineStaff()
    local list = {}

    for _, src in ipairs(staff.online('app')) do
        local who = staff.who(src)
        if who.license then list[who.license] = { level = Config.Levels[staff.rank(src)], name = who.name } end
    end

    return list
end

---How many reports were sent and closed each day for the last `days` days (oldest first), for everyone or for the
---staff member with `license` (then "sent" counts the reports they were first to answer).
---@param now integer
---@param days integer
---@param license? string
---@return { day: string, sent: integer, closed: integer }[]
function metrics.daily(now, days, license)
    local first = rules.periodStart('today', now) - (days - 1) * 86400
    local list = {}

    for i = 1, days do
        list[i] = { day = os.date(days > 7 and '%d' or '%a', first + (i - 1) * 86400), sent = 0, closed = 0 }
    end

    local sent, closed

    if license then
        sent = MySQL.query.await('SELECT FLOOR((`response_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `response_at` >= ? AND `response_license` = ? GROUP BY `d`', { first, first, license })
        closed = MySQL.query.await('SELECT FLOOR((`closed_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `closed_at` >= ? AND `closed_license` = ? GROUP BY `d`', { first, first, license })
    else
        sent = MySQL.query.await('SELECT FLOOR((`created_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `created_at` >= ? GROUP BY `d`', { first, first })
        closed = MySQL.query.await('SELECT FLOOR((`closed_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `closed_at` >= ? GROUP BY `d`', { first, first })
    end

    for _, row in ipairs(sent or {}) do
        local day = list[math.floor(tonumber(row.d)) + 1]
        if day then day.sent = tonumber(row.n) end
    end

    for _, row in ipairs(closed or {}) do
        local day = list[math.floor(tonumber(row.d)) + 1]
        if day then day.closed = tonumber(row.n) end
    end

    return list
end

---Each staff member's closed reports, rating and first-reply time since `since`, most closed first.
---@param since integer
---@return table[] rows with license (callers decide whether it leaves the server)
function metrics.reportsByStaff(since)
    local rows = MySQL.query.await([[
        SELECT `closed_license` AS `license`, MAX(`closed_name`) AS `name`, MAX(`closed_level`) AS `level`, COUNT(*) AS `closed`,
            AVG(`rating`) AS `rating`, COUNT(`rating`) AS `ratings`
        FROM `city_staff_reports` WHERE `closed_at` >= ? AND `closed_license` IS NOT NULL
        GROUP BY `closed_license` ORDER BY `closed` DESC LIMIT 50
    ]], { since }) or {}

    local responses = MySQL.query.await([[
        SELECT `response_license` AS `license`, AVG(`response_at` - `created_at`) AS `seconds`
        FROM `city_staff_reports` WHERE `created_at` >= ? AND `response_license` IS NOT NULL GROUP BY `response_license`
    ]], { since }) or {}

    local responseOf = {}

    for _, row in ipairs(responses) do
        responseOf[row.license] = tonumber(row.seconds)
    end

    local online = metrics.onlineStaff()

    for _, row in ipairs(rows) do
        row.rating = metrics.round1(row.rating)
        row.response = responseOf[row.license] and math.floor(responseOf[row.license]) or nil
        row.online = online[row.license] ~= nil
        row.level = online[row.license] and online[row.license].level or row.level
    end

    return rows
end

---The newest ratings, for everyone or for the staff member with `license`.
---@param limit integer
---@param license? string
---@return table[]
function metrics.latestRatings(limit, license)
    if license then
        return MySQL.query.await('SELECT `id`, `name`, `closed_name`, `rating`, `rating_tags`, `rating_comment`, `rated_at` FROM `city_staff_reports` WHERE `rating` IS NOT NULL AND `closed_license` = ? ORDER BY `rated_at` DESC LIMIT ?', { license, limit }) or {}
    end

    return MySQL.query.await('SELECT `id`, `name`, `closed_name`, `rating`, `rating_tags`, `rating_comment`, `rated_at` FROM `city_staff_reports` WHERE `rating` IS NOT NULL ORDER BY `rated_at` DESC LIMIT ?', { limit }) or {}
end

return metrics
