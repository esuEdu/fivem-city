-- The Team tab (admins): how each staff member is doing, from the reports they handled and the staff log.

local rules = require 'shared.rules'
local staff = require 'server.staff'
local metrics = require 'server.metrics'

local SANCTIONS = { warn = true, kick = true, ban = true }

---Every staff member with reports or logged actions since `since`, plus everyone on staff online now.
---@param since integer
---@return table[] most reports closed first, then most actions
local function members(since)
    local byLicense = {}

    local function member(license, name)
        if not byLicense[license] then
            byLicense[license] = { license = license, name = name, closed = 0, ratings = 0, actions = 0, sanctions = 0 }
        end

        return byLicense[license]
    end

    for _, row in ipairs(metrics.reportsByStaff(since)) do
        local entry = member(row.license, row.name)
        entry.closed, entry.rating, entry.ratings, entry.response, entry.level = row.closed, row.rating, row.ratings, row.response, row.level
    end

    local logged = MySQL.query.await([[
        SELECT `staff_license` AS `license`, MAX(`staff_name`) AS `name`, `action`, COUNT(*) AS `n`, UNIX_TIMESTAMP(MAX(`created_at`)) AS `last`
        FROM `city_staff_log` WHERE `created_at` >= FROM_UNIXTIME(?) AND `staff_license` IS NOT NULL
        GROUP BY `staff_license`, `action`
    ]], { since }) or {}

    for _, row in ipairs(logged) do
        local entry = member(row.license, row.name)
        local n = tonumber(row.n) or 0
        entry.actions = entry.actions + n
        if SANCTIONS[row.action] then entry.sanctions = entry.sanctions + n end
        entry.lastActive = math.max(entry.lastActive or 0, tonumber(row.last) or 0)
    end

    local online = metrics.onlineStaff()

    for license, info in pairs(online) do
        local entry = member(license, info.name)
        entry.level = info.level
    end

    local list = {}

    for _, entry in pairs(byLicense) do
        entry.online = online[entry.license] ~= nil
        list[#list + 1] = entry
    end

    table.sort(list, function(a, b)
        if a.closed ~= b.closed then return a.closed > b.closed end
        if a.actions ~= b.actions then return a.actions > b.actions end
        return (a.name or '') < (b.name or '')
    end)

    return list
end

staff.register('team', function(_, data)
    local since, period = rules.periodStart(data.period, os.time())

    return true, { period = period, members = members(since) }
end)

---@param value unknown
---@return string?
local function toLicense(value)
    return type(value) == 'string' and #value <= 60 and value:match('^[%w:]+$') and value or nil
end

staff.register('teamMember', function(_, data)
    local license = toLicense(data.license)
    if not license then return false, 'invalid' end

    local now = os.time()
    local since, period = rules.periodStart(data.period, now)
    local summary

    for _, entry in ipairs(members(since)) do
        if entry.license == license then summary = entry end
    end

    -- Someone with nothing in this period still has a page: their name from the log
    if not summary then
        local name = MySQL.scalar.await('SELECT `staff_name` FROM `city_staff_log` WHERE `staff_license` = ? ORDER BY `id` DESC LIMIT 1', { license })
        if not name then return false, 'not_found' end

        summary = { license = license, name = name, closed = 0, ratings = 0, actions = 0, sanctions = 0, online = metrics.onlineStaff()[license] ~= nil }
    end

    local breakdown = MySQL.query.await('SELECT `action`, COUNT(*) AS `n` FROM `city_staff_log` WHERE `staff_license` = ? AND `created_at` >= FROM_UNIXTIME(?) GROUP BY `action` ORDER BY `n` DESC', { license, since }) or {}
    local spread = MySQL.query.await('SELECT `rating`, COUNT(*) AS `n` FROM `city_staff_reports` WHERE `closed_license` = ? AND `rated_at` >= ? GROUP BY `rating`', { license, since }) or {}
    local recent = MySQL.query.await('SELECT `action`, `target_name`, `details`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `city_staff_log` WHERE `staff_license` = ? ORDER BY `id` DESC LIMIT 30', { license }) or {}

    local stars = { 0, 0, 0, 0, 0 }

    for _, row in ipairs(spread) do
        if stars[row.rating] then stars[row.rating] = tonumber(row.n) end
    end

    return true, {
        period = period,
        member = summary,
        chart = metrics.daily(now, 14, license),
        breakdown = breakdown,
        stars = stars,
        ratings = metrics.latestRatings(10, license),
        recent = recent,
    }
end, 'team')
