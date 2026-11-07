-- /report: players ask staff for help; online staff see the reports in the app (badge and banner), claim, reply, close.
-- Every report is saved in city_staff_reports (the dashboard's numbers come from there); open ones stay in memory too.
-- When staff close a report, the player who sent it is asked to rate them.

local rules = require 'shared.rules'
local staff = require 'server.staff'
local ratings = require 'server.ratings'

---@class Report
---@field id integer
---@field src? integer reporter's server id when sent (nil after a restart)
---@field citizenid string
---@field name string
---@field message string
---@field time integer
---@field claimedBy? string staff name
---@field claimedLicense? string
---@field responded boolean a staff member claimed or replied
---@field replies { name: string, text: string, time: integer }[]

---@type table<integer, Report> open reports by id
local open = {}

---@type table<string, integer> citizenid -> os.time() of their last report
local lastSent = {}

local ready = promise.new()

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_staff_reports` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `message` VARCHAR(300) NOT NULL,
            `replies` LONGTEXT NULL,
            `created_at` INT UNSIGNED NOT NULL,
            `response_at` INT UNSIGNED NULL,
            `response_license` VARCHAR(60) NULL,
            `claimed_name` VARCHAR(100) NULL,
            `claimed_license` VARCHAR(60) NULL,
            `closed_at` INT UNSIGNED NULL,
            `closed_name` VARCHAR(100) NULL,
            `closed_license` VARCHAR(60) NULL,
            `closed_level` VARCHAR(16) NULL,
            `rating` TINYINT UNSIGNED NULL,
            `rating_tags` VARCHAR(100) NULL,
            `rating_comment` VARCHAR(200) NULL,
            `rated_at` INT UNSIGNED NULL,
            PRIMARY KEY (`id`),
            KEY `created_at` (`created_at`),
            KEY `closed_at` (`closed_at`),
            KEY `rated_at` (`rated_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Reports still open from before a restart; their senders' server ids are gone
    local rows = MySQL.query.await('SELECT `id`, `citizenid`, `name`, `message`, `replies`, `created_at`, `response_at`, `claimed_name`, `claimed_license` FROM `city_staff_reports` WHERE `closed_at` IS NULL') or {}

    for _, row in ipairs(rows) do
        open[row.id] = {
            id = row.id,
            citizenid = row.citizenid,
            name = row.name,
            message = row.message,
            time = row.created_at,
            claimedBy = row.claimed_name,
            claimedLicense = row.claimed_license,
            responded = row.response_at ~= nil,
            replies = row.replies and json.decode(row.replies) or {},
        }
    end

    ready:resolve()
end)

---@return integer
local function openCount()
    local count = 0

    for _ in pairs(open) do
        count = count + 1
    end

    return count
end

---Tells online staff that reports changed: badge on the app icon, and the app reloads its list if it's open.
---@param note? { title: string, body: string, id: integer } a banner for a new report
local function broadcast(note)
    local count = openCount()

    for _, src in ipairs(staff.online('reports')) do
        exports.city_os:SetBadge(src, Config.App.id, count)
        TriggerClientEvent('city_staff:client:reportsChanged', src)

        if note then
            exports.city_os:Notify(src, { app = Config.App.id, title = note.title, body = note.body, banner = true, open = { tab = 'reports', id = note.id } })
        end
    end
end

---The reporter's server id if they are still online as the same character.
---@param report { src: integer?, citizenid: string }
---@return integer?
local function reporterOnline(report)
    local player = report.src and exports.qbx_core:GetPlayer(report.src)

    return player and player.PlayerData.citizenid == report.citizenid and report.src or nil
end

---Marks the first staff response (claim or reply), which the dashboard's response times use.
---@param report Report
---@param src integer
local function responded(report, src)
    if report.responded then return end

    report.responded = true
    MySQL.update('UPDATE `city_staff_reports` SET `response_at` = ?, `response_license` = ? WHERE `id` = ?', { os.time(), staff.who(src).license, report.id })
end

---@param report Report
---@param who { name: string, license: string? }
local function claim(report, who)
    report.claimedBy, report.claimedLicense = who.name, who.license
    MySQL.update('UPDATE `city_staff_reports` SET `claimed_name` = ?, `claimed_license` = ? WHERE `id` = ?', { who.name:sub(1, 100), who.license, report.id })
end

lib.addCommand('report', {
    help = locale('command_report'),
    params = { { name = 'message', type = 'longString', help = locale('param_report') } },
}, function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local message = rules.cleanText(args.message, Config.ReportMaxLength)
    if not message then return exports.qbx_core:Notify(src, locale('report_empty'), 'error') end

    local citizenid = player.PlayerData.citizenid
    local now = os.time()

    if lastSent[citizenid] and now - lastSent[citizenid] < Config.ReportCooldown then
        return exports.qbx_core:Notify(src, locale('report_wait', Config.ReportCooldown - (now - lastSent[citizenid])), 'error')
    end

    if openCount() >= Config.MaxReports then return exports.qbx_core:Notify(src, locale('report_full'), 'error') end

    lastSent[citizenid] = now
    Citizen.Await(ready)

    local charinfo = player.PlayerData.charinfo
    local name = ('%s %s (%s)'):format(charinfo.firstname, charinfo.lastname, GetPlayerName(src))
    local id = MySQL.insert.await('INSERT INTO `city_staff_reports` (`citizenid`, `name`, `message`, `created_at`) VALUES (?, ?, ?, ?)', {
        citizenid, name:sub(1, 100), message, now,
    })
    if not id then return exports.qbx_core:Notify(src, locale('error_failed'), 'error') end

    open[id] = { id = id, src = src, citizenid = citizenid, name = name, message = message, time = now, responded = false, replies = {} }

    exports.qbx_core:Notify(src, locale('report_sent', id), 'success')
    broadcast({ title = locale('report_new', id), body = ('%s: %s'):format(name, message), id = id })
end)

---@param report table
---@param myLicense? string
---@return table as the app shows it
local function toApp(report, myLicense)
    return {
        id = report.id,
        target = reporterOnline(report),
        name = report.name,
        message = report.message,
        time = report.time,
        claimedBy = report.claimedBy,
        mine = myLicense ~= nil and report.claimedLicense == myLicense,
        replies = report.replies,
        closed = report.closed or false,
        closedBy = report.closedBy,
        rating = report.rating,
        ratingTags = report.ratingTags,
        ratingComment = report.ratingComment,
    }
end

-- Open reports (newest first), then the last closed ones from the database
staff.register('reports', function(src)
    Citizen.Await(ready)

    local myLicense = staff.who(src).license
    local list = {}

    for _, report in pairs(open) do
        list[#list + 1] = toApp(report, myLicense)
    end

    table.sort(list, function(a, b) return a.id > b.id end)

    local closed = MySQL.query.await('SELECT `id`, `citizenid`, `name`, `message`, `replies`, `created_at`, `claimed_name`, `claimed_license`, `closed_name`, `rating`, `rating_tags`, `rating_comment` FROM `city_staff_reports` WHERE `closed_at` IS NOT NULL ORDER BY `closed_at` DESC LIMIT 50') or {}

    for _, row in ipairs(closed) do
        list[#list + 1] = toApp({
            id = row.id, citizenid = row.citizenid, name = row.name, message = row.message, time = row.created_at,
            claimedBy = row.claimed_name, claimedLicense = row.claimed_license, replies = row.replies and json.decode(row.replies) or {},
            closed = true, closedBy = row.closed_name, rating = row.rating, ratingTags = row.rating_tags, ratingComment = row.rating_comment,
        }, myLicense)
    end

    -- Opening the list also fixes a badge that went stale
    exports.city_os:SetBadge(src, Config.App.id, openCount())

    return true, list
end)

staff.register('claimReport', function(src, data)
    local report = open[rules.toId(data.id) or -1]
    if not report then return false, 'not_found' end

    claim(report, staff.who(src))
    responded(report, src)
    staff.log(src, 'claimReport', { name = report.name, citizenid = report.citizenid }, ('#%d'):format(report.id))
    broadcast()

    return true
end, 'reports')

staff.register('replyReport', function(src, data)
    local report = open[rules.toId(data.id) or -1]
    if not report then return false, 'not_found' end

    local text = rules.cleanText(data.text, Config.ReportMaxLength)
    if not text then return false, 'no_reason' end

    local who = staff.who(src)
    if not report.claimedBy then claim(report, who) end

    report.replies[#report.replies + 1] = { name = who.name, text = text, time = os.time() }
    responded(report, src)
    MySQL.update('UPDATE `city_staff_reports` SET `replies` = ? WHERE `id` = ?', { json.encode(report.replies), report.id })

    local reporter = reporterOnline(report)
    if reporter then exports.qbx_core:Notify(reporter, text, 'inform', 15000, locale('report_reply', report.id)) end

    staff.log(src, 'replyReport', { name = report.name, citizenid = report.citizenid }, ('#%d: %s'):format(report.id, text))
    broadcast()

    return true
end, 'reports')

-- Closing asks the reporter (if still online) to rate the staff member who closed it
staff.register('closeReport', function(src, data)
    local report = open[rules.toId(data.id) or -1]
    if not report then return false, 'not_found' end

    local who = staff.who(src)
    open[report.id] = nil
    responded(report, src)

    MySQL.update('UPDATE `city_staff_reports` SET `closed_at` = ?, `closed_name` = ?, `closed_license` = ?, `closed_level` = ? WHERE `id` = ?', {
        os.time(), who.name:sub(1, 100), who.license, Config.Levels[staff.rank(src)], report.id,
    })

    local reporter = reporterOnline(report)

    if reporter then
        ratings.ask(report.id, report.citizenid)
        TriggerClientEvent('city_staff:client:askRating', reporter, { id = report.id, staff = who.name, message = report.message, tags = Config.RatingTags })
    end

    staff.log(src, 'closeReport', { name = report.name, citizenid = report.citizenid }, ('#%d'):format(report.id))
    broadcast()

    return true
end, 'reports')
