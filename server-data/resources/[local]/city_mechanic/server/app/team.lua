-- The Team tab: everyone with the job (online or not) and, for the boss, hire, change grade and fire.

local core = require 'server.app.core'
local services = require 'server.app.services'

---Names of offline members, in one query.
---@param citizenids string[]
---@return table<string, string>
local function offlineNames(citizenids)
    local names = {}
    if #citizenids == 0 then return names end

    local marks = ('?,'):rep(#citizenids):sub(1, -2)
    local rows = MySQL.query.await(('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(marks), citizenids) or {}

    for _, row in ipairs(rows) do
        local info = json.decode(row.charinfo or '{}') or {}
        names[row.citizenid] = ('%s %s'):format(info.firstname or '?', info.lastname or '')
    end

    return names
end

---@param me string the viewer's citizenid
---@return table[]
local function members(me)
    local job = exports.qbx_core:GetJob(Config.Job)
    local week = services.stats(me).byMember
    local list, offline = {}, {}

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        local online = exports.qbx_core:GetPlayerByCitizenId(member.citizenid)
        local onJob = online and online.PlayerData.job.name == Config.Job
        local grade = job.grades[member.grade]

        list[#list + 1] = {
            citizenid = member.citizenid,
            name = online and core.fullName(online) or nil,
            grade = member.grade,
            gradeName = grade and grade.name or tostring(member.grade),
            boss = grade and grade.isboss == true or false,
            online = online ~= nil,
            onDuty = onJob and online.PlayerData.job.onduty == true or false,
            week = week[member.citizenid] or 0,
            me = member.citizenid == me,
        }

        if not online then offline[#offline + 1] = member.citizenid end
    end

    local names = offlineNames(offline)

    for _, member in ipairs(list) do
        member.name = member.name or names[member.citizenid] or member.citizenid
    end

    table.sort(list, function(a, b)
        if a.onDuty ~= b.onDuty then return a.onDuty end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)

    return list
end

core.register('team', function(_, player)
    return true, members(player.PlayerData.citizenid)
end)

---A member the boss may change: in the job, below the boss's own grade, not themselves.
---@param player table the boss
---@param citizenid unknown
---@return string?
local function subordinate(player, citizenid)
    citizenid = core.citizenid(citizenid)
    if not citizenid or citizenid == player.PlayerData.citizenid then return end

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        if member.citizenid == citizenid and member.grade < player.PlayerData.job.grade.level then return citizenid end
    end
end

core.register('setGrade', function(src, player, data)
    local citizenid = subordinate(player, data.citizenid)
    local grade = math.tointeger(data.grade)
    local job = exports.qbx_core:GetJob(Config.Job)

    if not citizenid or not grade or not job.grades[grade] or grade >= player.PlayerData.job.grade.level then return false, 'invalid' end
    if not exports.qbx_core:AddPlayerToJob(citizenid, Config.Job, grade) then return false, 'failed' end

    lib.print.info(('city_mechanic: %s (%s) set %s to grade %d'):format(player.PlayerData.citizenid, src, citizenid, grade))

    return true
end, { boss = true })

core.register('fire', function(src, player, data)
    local citizenid = subordinate(player, data.citizenid)
    if not citizenid then return false, 'invalid' end
    if not exports.qbx_core:RemovePlayerFromJob(citizenid, Config.Job) then return false, 'failed' end

    lib.print.info(('city_mechanic: %s (%s) fired %s'):format(player.PlayerData.citizenid, src, citizenid))

    return true
end, { boss = true })

-- The Hire tab: online players who don't work here yet, with their server id and current job
core.register('candidates', function(src)
    local members = {}
    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        members[member.citizenid] = true
    end

    local list = {}

    for target, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if target ~= src and not members[player.PlayerData.citizenid] then
            local job = player.PlayerData.job

            list[#list + 1] = {
                id = target,
                name = core.fullName(player),
                job = job and job.name ~= 'unemployed' and job.label or nil,
            }
        end
    end

    table.sort(list, function(a, b) return a.id < b.id end)

    return true, list
end, { boss = true })

-- Any online player, by server id, at the lowest grade
core.register('hire', function(src, player, data)
    local target = math.tointeger(data.target)
    local hired = target and target ~= src and exports.qbx_core:GetPlayer(target)
    if not hired then return false, 'no_player' end

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        if member.citizenid == hired.PlayerData.citizenid then return false, 'already' end
    end

    if not exports.qbx_core:SetJob(target, Config.Job, 0) then return false, 'failed' end

    exports.qbx_core:Notify(target, locale('hired_you', Config.Label), 'success')
    lib.print.info(('city_mechanic: %s (%s) hired %s'):format(player.PlayerData.citizenid, src, hired.PlayerData.citizenid))

    return true, core.fullName(hired)
end, { boss = true })
