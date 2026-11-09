-- The Dashboard and Members tabs: the gang's and each member's performance, and promoting, demoting, firing, leaving.
local rules = require 'shared.rules'
local gang = require 'server.gang'
local log = require 'server.log'

---Every member of a gang from qbx_core's player_groups, with names, grades and who is online
---@param group table gang.of result
---@return table[] highest grade first, then by name
local function members(group)
    local rows = exports.qbx_core:GetGroupMembers(group.name, 'gang') or {}
    if #rows == 0 then return {} end

    local ids = {}

    for i = 1, #rows do ids[i] = rows[i].citizenid end

    local info = {}
    local players = MySQL.query.await('SELECT `citizenid`, `charinfo`, UNIX_TIMESTAMP(`last_updated`) AS `seen` FROM `players` WHERE `citizenid` IN (?)', { ids }) or {}

    for _, row in ipairs(players) do info[row.citizenid] = row end

    local list = {}

    for _, row in ipairs(rows) do
        local grade = tonumber(row.grade) or 0
        local definition = group.grades[grade] or {}
        local online = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
        local saved = info[row.citizenid]

        list[#list + 1] = {
            citizenid = row.citizenid,
            name = online and gang.name(online.PlayerData.charinfo) or saved and gang.name(json.decode(saved.charinfo or 'null')) or row.citizenid,
            grade = grade,
            gradeName = definition.name or tostring(grade),
            isboss = definition.isboss == true,
            online = online ~= nil,
            source = online and online.PlayerData.source or nil,
            seen = saved and tonumber(saved.seen) or nil,
        }
    end

    table.sort(list, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)

    return list
end

---One member of this gang by citizenid
---@return table?
local function findMember(group, citizenid)
    for _, member in ipairs(members(group)) do
        if member.citizenid == citizenid then return member end
    end
end

---The period the page asked for, and when it started
---@return integer days, integer since
local function periodOf(data)
    local days = rules.period(math.tointeger(data.days), Config.Periods, Config.StatsDays)

    return days, rules.since(os.time(), days)
end

---The last Config.ChartDays days, day by day, for the whole gang or one member
local function chart(group, citizenid)
    local start = rules.since(os.time(), Config.ChartDays)

    return { start = start, days = rules.series(log.daily(group.name, start, citizenid), Config.ChartDays) }
end

---Each member with what they did in the period, sorted by money earned
local function performance(list, stats)
    local ranked = {}

    for _, member in ipairs(list) do
        local done = stats.members[member.citizenid] or {}

        ranked[#ranked + 1] = {
            citizenid = member.citizenid,
            name = member.name,
            gradeName = member.gradeName,
            online = member.online,
            earned = done.earned or 0,
            sales = done.sales or 0,
            made = done.made or 0,
        }
    end

    table.sort(ranked, function(a, b)
        if a.earned ~= b.earned then return a.earned > b.earned end
        return a.made > b.made
    end)

    return ranked
end

-- The dashboard: the gang's numbers for the period, day by day, per drug and every member's
gang.register('overview', function(_, _, group, data)
    local days, since = periodOf(data)
    local list = members(group)
    local stats = log.stats(group.name, since)
    local online, active = 0, 0
    local ranked = performance(list, stats)

    for _, member in ipairs(ranked) do
        if member.online then online = online + 1 end
        if member.sales > 0 or member.made > 0 then active = active + 1 end
    end

    return true, {
        days = days,
        members = #list,
        online = online,
        active = active,
        sales = stats.sales,
        earned = stats.earned,
        made = stats.made,
        average = stats.sales > 0 and math.floor(stats.earned / stats.sales) or 0,
        drugs = stats.drugs,
        ranking = ranked,
        chart = chart(group),
    }
end, 'app')

gang.register('members', function(_, player, group, data)
    local days, since = periodOf(data)
    local list = members(group)
    local stats = log.stats(group.name, since)
    local me = player.PlayerData.citizenid

    for _, member in ipairs(list) do
        local done = stats.members[member.citizenid] or {}
        member.earned, member.sales, member.made = done.earned or 0, done.sales or 0, done.made or 0
        member.isMe = member.citizenid == me
        member.source = nil
    end

    return true, { members = list, days = days }
end, 'app')

-- One member's performance page: their numbers, where they stand in the gang, day by day, per drug, and their log
gang.register('member', function(_, player, group, data)
    local citizenid = gang.toCitizenId(data.citizenid)
    if not citizenid then return false, 'invalid' end

    local days, since = periodOf(data)
    local list = members(group)
    local member

    for _, entry in ipairs(list) do
        if entry.citizenid == citizenid then member = entry end
    end

    if not member then return false, 'not_member' end

    local gangStats = log.stats(group.name, since)
    local mine = log.stats(group.name, since, citizenid)
    local place, share = rules.standing(performance(list, gangStats), citizenid)

    member.source = nil
    member.isMe = citizenid == player.PlayerData.citizenid
    member.canManage = rules.outranks(group.grade, member.grade, member.isMe)

    return true, {
        days = days,
        member = member,
        earned = mine.earned,
        sales = mine.sales,
        made = mine.made,
        average = mine.sales > 0 and math.floor(mine.earned / mine.sales) or 0,
        place = (mine.earned > 0 or mine.made > 0) and place or nil,
        share = share,
        size = #list,
        drugs = mine.drugs,
        chart = chart(group, citizenid),
        recent = log.member(group.name, citizenid, 25),
    }
end, 'app')

gang.register('setGrade', function(src, player, group, data)
    local citizenid = gang.toCitizenId(data.citizenid)
    local newGrade = math.tointeger(data.grade)
    if not citizenid or not newGrade then return false, 'invalid' end

    local target = findMember(group, citizenid)
    if not target then return false, 'not_member' end

    if not rules.canSetGrade(group.grade, target.grade, newGrade, group.grades) then return false, 'outranked' end

    local ok = exports.qbx_core:AddPlayerToGang(citizenid, group.name, newGrade)
    if not ok then return false, 'failed' end

    local gradeName = group.grades[newGrade].name or tostring(newGrade)
    log.add(group.name, gang.who(player), newGrade > target.grade and 'promote' or 'demote', target, nil, gradeName)
    gang.notify(target.source, locale('notify_grade', group.label, gradeName))

    return true
end)

gang.register('fire', function(src, player, group, data)
    local citizenid = gang.toCitizenId(data.citizenid)
    if not citizenid then return false, 'invalid' end

    local target = findMember(group, citizenid)
    if not target then return false, 'not_member' end

    if not rules.outranks(group.grade, target.grade, citizenid == player.PlayerData.citizenid) then return false, 'outranked' end

    local ok = exports.qbx_core:RemovePlayerFromGang(citizenid, group.name)
    if not ok then return false, 'failed' end

    log.add(group.name, gang.who(player), 'fire', target)
    gang.notify(target.source, locale('notify_fired', group.label), 'error')

    return true
end)

gang.register('leave', function(src, player, group)
    local bosses = 0

    for _, member in ipairs(members(group)) do
        if member.isboss then bosses = bosses + 1 end
    end

    if not rules.canLeave(group.isboss, bosses) then return false, 'last_boss' end

    local ok = exports.qbx_core:RemovePlayerFromGang(player.PlayerData.citizenid, group.name)
    if not ok then return false, 'failed' end

    log.add(group.name, gang.who(player), 'leave')

    return true
end, 'app')
