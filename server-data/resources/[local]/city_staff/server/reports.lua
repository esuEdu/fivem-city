-- /report: players ask staff for help; online staff see the reports in the app (badge and banner), claim, reply, close.
-- Kept in memory; lost on restart. Every staff step is in the staff log.

local rules = require 'shared.rules'
local staff = require 'server.staff'

---@class Report
---@field id integer
---@field src integer reporter's server id when sent
---@field citizenid string
---@field name string
---@field message string
---@field time integer
---@field claimedBy? string staff name
---@field replies { name: string, text: string, time: integer }[]
---@field closed boolean

---@type Report[] oldest first
local reports = {}
local lastId = 0

---@type table<string, integer> citizenid -> os.time() of their last report
local lastSent = {}

---@return integer
local function openCount()
    local count = 0

    for _, report in ipairs(reports) do
        if not report.closed then count = count + 1 end
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

---@param id unknown
---@return Report?
local function find(id)
    id = rules.toId(id)

    for _, report in ipairs(reports) do
        if report.id == id then return report end
    end
end

---The reporter's server id if they are still online as the same character.
---@param report Report
---@return integer?
local function reporterOnline(report)
    local player = exports.qbx_core:GetPlayer(report.src)

    return player and player.PlayerData.citizenid == report.citizenid and report.src or nil
end

---Makes room for a new report by dropping the oldest closed one. False when every report is still open.
---@return boolean
local function makeRoom()
    if #reports < Config.MaxReports then return true end

    for i, report in ipairs(reports) do
        if report.closed then
            table.remove(reports, i)
            return true
        end
    end

    return false
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

    if not makeRoom() then return exports.qbx_core:Notify(src, locale('report_full'), 'error') end

    lastSent[citizenid] = now
    lastId = lastId + 1

    local charinfo = player.PlayerData.charinfo
    local report = {
        id = lastId,
        src = src,
        citizenid = citizenid,
        name = ('%s %s (%s)'):format(charinfo.firstname, charinfo.lastname, GetPlayerName(src)),
        message = message,
        time = now,
        replies = {},
        closed = false,
    }

    reports[#reports + 1] = report
    exports.qbx_core:Notify(src, locale('report_sent', report.id), 'success')
    broadcast({ title = locale('report_new', report.id), body = ('%s: %s'):format(report.name, message), id = report.id })
end)

staff.register('reports', function(src)
    local list = {}

    for i = #reports, 1, -1 do
        local report = reports[i]

        list[#list + 1] = {
            id = report.id,
            target = reporterOnline(report),
            name = report.name,
            message = report.message,
            time = report.time,
            claimedBy = report.claimedBy,
            replies = report.replies,
            closed = report.closed,
        }
    end

    -- Opening the list also fixes a badge that went stale
    exports.city_os:SetBadge(src, Config.App.id, openCount())

    return true, list
end)

staff.register('claimReport', function(src, data)
    local report = find(data.id)
    if not report or report.closed then return false, 'not_found' end

    report.claimedBy = staff.who(src).name
    staff.log(src, 'claimReport', { name = report.name, citizenid = report.citizenid }, ('#%d'):format(report.id))
    broadcast()

    return true
end, 'reports')

staff.register('replyReport', function(src, data)
    local report = find(data.id)
    if not report or report.closed then return false, 'not_found' end

    local text = rules.cleanText(data.text, Config.ReportMaxLength)
    if not text then return false, 'no_reason' end

    local name = staff.who(src).name
    report.claimedBy = report.claimedBy or name
    report.replies[#report.replies + 1] = { name = name, text = text, time = os.time() }

    local reporter = reporterOnline(report)
    if reporter then exports.qbx_core:Notify(reporter, text, 'inform', 15000, locale('report_reply', report.id)) end

    staff.log(src, 'replyReport', { name = report.name, citizenid = report.citizenid }, ('#%d: %s'):format(report.id, text))
    broadcast()

    return true
end, 'reports')

staff.register('closeReport', function(src, data)
    local report = find(data.id)
    if not report or report.closed then return false, 'not_found' end

    report.closed = true

    local reporter = reporterOnline(report)
    if reporter then exports.qbx_core:Notify(reporter, locale('report_closed', report.id), 'inform') end

    staff.log(src, 'closeReport', { name = report.name, citizenid = report.citizenid }, ('#%d'):format(report.id))
    broadcast()

    return true
end, 'reports')
