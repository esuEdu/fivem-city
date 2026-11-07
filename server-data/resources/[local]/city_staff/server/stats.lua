-- Dashboard and Ratings numbers, worked out from city_staff_reports (server/reports.lua creates it).

local rules = require 'shared.rules'
local staff = require 'server.staff'

local CHART_DAYS = 7

---@param value unknown
---@return number?
local function round1(value)
    value = tonumber(value)
    return value and math.floor(value * 10 + 0.5) / 10 or nil
end

---Staff on the server right now, by license, with their level.
---@return table<string, string> license -> level
local function onlineStaff()
    local list = {}

    for _, src in ipairs(staff.online('app')) do
        local license = staff.who(src).license
        if license then list[license] = Config.Levels[staff.rank(src)] end
    end

    return list
end

---Reports sent and closed per day, for the last CHART_DAYS days (oldest first).
---@param now integer
---@return { day: string, sent: integer, closed: integer }[]
local function chart(now)
    local today = rules.periodStart('today', now)
    local first = today - (CHART_DAYS - 1) * 86400
    local days = {}

    for i = 1, CHART_DAYS do
        days[i] = { day = os.date('%a', first + (i - 1) * 86400), sent = 0, closed = 0 }
    end

    local sent = MySQL.query.await('SELECT FLOOR((`created_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `created_at` >= ? GROUP BY `d`', { first, first }) or {}
    local closed = MySQL.query.await('SELECT FLOOR((`closed_at` - ?) / 86400) AS `d`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `closed_at` >= ? GROUP BY `d`', { first, first }) or {}

    for _, row in ipairs(sent) do
        local day = days[math.floor(tonumber(row.d)) + 1]
        if day then day.sent = tonumber(row.n) end
    end

    for _, row in ipairs(closed) do
        local day = days[math.floor(tonumber(row.d)) + 1]
        if day then day.closed = tonumber(row.n) end
    end

    return days
end

---Each staff member's closed reports, rating and response time since `since`, most closed first.
---@param since integer
---@return table[]
local function team(since)
    local rows = MySQL.query.await([[
        SELECT `closed_license` AS `license`, MAX(`closed_name`) AS `name`, MAX(`closed_level`) AS `level`, COUNT(*) AS `closed`,
            AVG(`rating`) AS `rating`, COUNT(`rating`) AS `ratings`
        FROM `city_staff_reports` WHERE `closed_at` >= ? AND `closed_license` IS NOT NULL
        GROUP BY `closed_license` ORDER BY `closed` DESC LIMIT 20
    ]], { since }) or {}

    local responses = MySQL.query.await([[
        SELECT `response_license` AS `license`, AVG(`response_at` - `created_at`) AS `seconds`
        FROM `city_staff_reports` WHERE `created_at` >= ? AND `response_license` IS NOT NULL GROUP BY `response_license`
    ]], { since }) or {}

    local responseOf = {}
    for _, row in ipairs(responses) do
        responseOf[row.license] = tonumber(row.seconds)
    end

    local online = onlineStaff()

    for _, row in ipairs(rows) do
        row.rating = round1(row.rating)
        row.response = responseOf[row.license] and math.floor(responseOf[row.license]) or nil
        row.online = online[row.license] ~= nil
        row.level = online[row.license] or row.level
    end

    return rows
end

---@param limit integer
---@return table[]
local function latestRatings(limit)
    return MySQL.query.await('SELECT `id`, `name`, `closed_name`, `rating`, `rating_tags`, `rating_comment`, `rated_at` FROM `city_staff_reports` WHERE `rating` IS NOT NULL ORDER BY `rated_at` DESC LIMIT ?', { limit }) or {}
end

staff.register('dashboard', function(src, data)
    local now = os.time()
    local since, period = rules.periodStart(data.period, now)
    local length = now - since

    local closed = MySQL.scalar.await('SELECT COUNT(*) FROM `city_staff_reports` WHERE `closed_at` >= ?', { since }) or 0
    local closedBefore = MySQL.scalar.await('SELECT COUNT(*) FROM `city_staff_reports` WHERE `closed_at` >= ? AND `closed_at` < ?', { since - length, since }) or 0
    local openCount = MySQL.scalar.await('SELECT COUNT(*) FROM `city_staff_reports` WHERE `closed_at` IS NULL') or 0
    local oldestOpen = MySQL.scalar.await('SELECT MIN(`created_at`) FROM `city_staff_reports` WHERE `closed_at` IS NULL AND `response_at` IS NULL')
    local response = MySQL.scalar.await('SELECT AVG(`response_at` - `created_at`) FROM `city_staff_reports` WHERE `created_at` >= ? AND `response_at` IS NOT NULL', { since })
    local rating = MySQL.single.await('SELECT AVG(`rating`) AS `average`, COUNT(`rating`) AS `count` FROM `city_staff_reports` WHERE `rated_at` >= ?', { since }) or {}

    local members = team(since)
    local myLicense = staff.who(src).license
    local me = { closed = 0, goal = Config.Goals[period] }

    for rank, member in ipairs(members) do
        if member.license == myLicense then
            me = { closed = member.closed, goal = Config.Goals[period], rank = rank, rating = member.rating, ratings = member.ratings, response = member.response }
        end

        -- Other staff's licenses stay on the server
        member.license = nil
    end

    local online = 0

    for _ in pairs(onlineStaff()) do
        online = online + 1
    end

    return true, {
        period = period,
        open = openCount,
        waitingSince = oldestOpen and now - oldestOpen or nil,
        closed = closed,
        closedBefore = closedBefore,
        response = tonumber(response) and math.floor(tonumber(response)) or nil,
        rating = round1(rating.average),
        ratings = rating.count or 0,
        chart = chart(now),
        team = members,
        teamSize = #members,
        me = me,
        staffOnline = online,
        latest = latestRatings(3),
    }
end, 'app')

-- The last 30 days of ratings, and the 30 before them for each staff member's trend
staff.register('ratings', function()
    local now = os.time()
    local since = now - 30 * 86400

    local summary = MySQL.single.await('SELECT AVG(`rating`) AS `average`, COUNT(`rating`) AS `count`, COUNT(*) AS `closed` FROM `city_staff_reports` WHERE `closed_at` >= ?', { since }) or {}
    local spread = MySQL.query.await('SELECT `rating`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `rated_at` >= ? GROUP BY `rating`', { since }) or {}
    local before = MySQL.query.await('SELECT `closed_license` AS `license`, AVG(`rating`) AS `rating` FROM `city_staff_reports` WHERE `rated_at` >= ? AND `rated_at` < ? GROUP BY `closed_license`', { since - 30 * 86400, since }) or {}

    local stars = { 0, 0, 0, 0, 0 }

    for _, row in ipairs(spread) do
        if stars[row.rating] then stars[row.rating] = tonumber(row.n) end
    end

    local previous = {}

    for _, row in ipairs(before) do
        previous[row.license] = tonumber(row.rating)
    end

    local members = team(since)

    for _, member in ipairs(members) do
        local old = previous[member.license]
        member.trend = member.rating and old and round1(member.rating - old) or nil
        member.license = nil
    end

    return true, {
        rating = round1(summary.average),
        ratings = summary.count or 0,
        closed = summary.closed or 0,
        stars = stars,
        team = members,
        latest = latestRatings(30),
    }
end)
