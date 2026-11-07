-- The Dashboard and Ratings tabs (numbers from server/metrics.lua; server/reports.lua creates the table).

local rules = require 'shared.rules'
local staff = require 'server.staff'
local metrics = require 'server.metrics'
local goals = require 'server.goals'

local CHART_DAYS = 7

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

    local members = metrics.reportsByStaff(since)
    local myLicense = staff.who(src).license
    local goal = goals.get()[period]
    local me = { closed = 0, goal = goal }

    for rank, member in ipairs(members) do
        if member.license == myLicense then
            me = { closed = member.closed, goal = goal, rank = rank, rating = member.rating, ratings = member.ratings, response = member.response }
        end

        -- Other staff's licenses stay on the server
        member.license = nil
    end

    local online = 0

    for _ in pairs(metrics.onlineStaff()) do
        online = online + 1
    end

    return true, {
        period = period,
        open = openCount,
        waitingSince = oldestOpen and now - oldestOpen or nil,
        closed = closed,
        closedBefore = closedBefore,
        response = tonumber(response) and math.floor(tonumber(response)) or nil,
        rating = metrics.round1(rating.average),
        ratings = rating.count or 0,
        chart = metrics.daily(now, CHART_DAYS),
        team = members,
        teamSize = #members,
        me = me,
        staffOnline = online,
        latest = metrics.latestRatings(3),
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

    local members = metrics.reportsByStaff(since)

    for _, member in ipairs(members) do
        local old = previous[member.license]
        member.trend = member.rating and old and metrics.round1(member.rating - old) or nil
        member.license = nil
    end

    return true, {
        rating = metrics.round1(summary.average),
        ratings = summary.count or 0,
        closed = summary.closed or 0,
        stars = stars,
        team = members,
        latest = metrics.latestRatings(30),
    }
end)
