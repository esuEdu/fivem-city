-- The EMS app: what it loads on open, the dashboard, the records (revives and bills) and the calls' notification and
-- badge. The calls themselves live in server/sos.lua; the page reads and answers them through its callbacks.

local core = require 'server.app.core'
local records = require 'server.app.records'
local settings = require 'server.config'
local sos = require 'server.sos'

---@param job table qbx job
---@return { level: integer, name: string, boss: boolean }[]
local function grades(job)
    local list = {}

    for level, grade in pairs(job.grades) do
        list[#list + 1] = { level = level, name = grade.name, boss = grade.isboss == true }
    end

    table.sort(list, function(a, b) return a.level < b.level end)

    return list
end

core.register('app', function(_, player)
    local job = player.PlayerData.job

    return true, {
        me = core.fullName(player),
        citizenid = player.PlayerData.citizenid,
        grade = job.grade.name,
        gradeLevel = job.grade.level,
        boss = job.isboss == true,
        onDuty = job.onduty == true,
        shop = Config.App.employer,
        grades = grades(exports.qbx_core:GetJob(Config.Job)),
        prices = { billing = settings.billing, maxBill = settings.prices.maxBill },
        calls = core.openCalls(),
    }
end)

core.register('dashboard', function(_, player)
    local stats = records.stats(player.PlayerData.citizenid)
    local onDuty = {}

    for src, duty in pairs(core.onlineMembers()) do
        if duty then
            local member = exports.qbx_core:GetPlayer(src)
            onDuty[#onDuty + 1] = { name = core.fullName(member), grade = member.PlayerData.job.grade.name }
        end
    end

    table.sort(onDuty, function(a, b) return a.name < b.name end)

    return true, {
        onDuty = onDuty,
        calls = core.openCalls(),
        revives = stats.revivesToday,
        billed = stats.billedToday,
        week = stats.weekCount,
        mine = stats.mine,
        days = stats.days,
        latest = records.recent(5),
        myDuty = player.PlayerData.job.onduty == true,
    }
end)

core.register('records', function()
    return true, records.recent(Config.App.historyLimit)
end)

sos.onChange(function(id)
    for src, duty in pairs(core.onlineMembers()) do
        if duty then
            if id then
                exports.city_os:Notify(src, {
                    app = Config.App.id,
                    title = locale('app_new_call'),
                    body = locale('app_new_call_body'),
                    banner = true,
                    open = { tab = 'calls', id = id },
                })
            end

            TriggerClientEvent('city_hospital:client:appMessage', src, { type = 'calls' })
        end
    end

    core.updateBadges()
end)

-- Calls expire on their own and duty changes; a slow refresh keeps the badges right
CreateThread(function()
    while true do
        Wait(60000)
        core.updateBadges()
    end
end)
