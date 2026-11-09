-- The Mechanic app: what it loads on open, the dashboard, the service history and the 555 calls' notification and badge.
-- The calls themselves live in city_dispatch; the page reads and answers them through its callbacks (client/app.lua).

local core = require 'server.app.core'
local services = require 'server.app.services'
local catalog = require 'shared.catalog'

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

-- The reference price list mechanics charge customers from (the bay's own prices)
local function priceList()
    local prices = Config.Prices
    local performance = {}

    for _, entry in ipairs(catalog.performance) do
        performance[#performance + 1] = { label = entry.label, levels = prices.performance[entry.key] or {} }
    end

    return {
        flat = {
            { key = 'part', price = prices.part },
            { key = 'paint', price = prices.paint },
            { key = 'wheels', price = prices.wheels },
            { key = 'tyres', price = prices.tyres },
            { key = 'lights', price = prices.lights },
            { key = 'tint', price = prices.tint },
            { key = 'plate', price = prices.plate },
            { key = 'horn', price = prices.horn },
            { key = 'turbo', price = prices.turbo },
        },
        performance = performance,
        repairPerPoint = prices.repairPerPoint,
    }
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
        shop = Config.Label,
        grades = grades(exports.qbx_core:GetJob(Config.Job)),
        prices = priceList(),
        calls = core.openCalls(),
    }
end)

core.register('dashboard', function(_, player)
    local stats = services.stats(player.PlayerData.citizenid)
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
        today = stats.todayCount,
        todayValue = stats.todayValue,
        week = stats.weekCount,
        mine = stats.mine,
        days = stats.days,
        latest = services.recent(5),
        myDuty = player.PlayerData.job.onduty == true,
    }
end)

core.register('services', function()
    return true, services.recent(Config.App.historyLimit)
end)

AddEventHandler('city_dispatch:server:callsChanged', function(service, id)
    if GetInvokingResource() ~= 'city_dispatch' or service ~= Config.App.service then return end

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

            TriggerClientEvent('city_mechanic:client:appMessage', src, { type = 'calls' })
        end
    end

    core.updateBadges()
end)

-- Calls expire on their own in city_dispatch, and duty changes; a slow refresh keeps the badges right
CreateThread(function()
    while true do
        Wait(60000)
        core.updateBadges()
    end
end)
