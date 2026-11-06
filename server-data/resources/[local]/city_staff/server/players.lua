-- The player list and everything staff do to one player (except warnings, kicks and bans: server/sanctions.lua).

local rules = require 'shared.rules'
local staff = require 'server.staff'

---@type table<integer, true> players frozen by staff
local frozen = {}

---@type table<integer, integer> staff spectating -> the routing bucket they came from
local spectating = {}

---@param src integer
---@return table row as the player list shows it
local function row(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = player.PlayerData

    return {
        id = src,
        name = ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname),
        account = GetPlayerName(src),
        citizenid = data.citizenid,
        job = data.job.label,
    }
end

staff.register('players', function()
    local list = {}

    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        list[#list + 1] = row(src)
    end

    table.sort(list, function(a, b) return a.id < b.id end)

    return true, list
end, 'app')

staff.register('player', function(_, data)
    local target = rules.toId(data.target)
    local player = target and exports.qbx_core:GetPlayer(target)
    if not player then return false, 'no_player' end

    local info = row(target)
    local playerData = player.PlayerData
    local license = GetPlayerIdentifierByType(tostring(target), 'license2') or GetPlayerIdentifierByType(tostring(target), 'license')

    info.jobGrade = playerData.job.grade and playerData.job.grade.name
    info.gang = playerData.gang.label
    info.gangGrade = playerData.gang.grade and playerData.gang.grade.name
    info.ping = GetPlayerPing(tostring(target))
    info.bucket = GetPlayerRoutingBucket(tostring(target))
    info.frozen = frozen[target] == true
    info.staff = Config.Levels[staff.rank(target)]
    info.license = license
    info.dead = playerData.metadata.isdead or playerData.metadata.inlaststand or false
    info.cuffed = playerData.metadata.ishandcuffed or false
    info.warnings = MySQL.query.await('SELECT `reason`, `staff_name`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `city_staff_warnings` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20', { playerData.citizenid }) or {}

    return true, info
end, 'app')

---Puts `who` in `into`'s routing bucket, so they can see each other.
---@param who integer
---@param into integer
local function matchBucket(who, into)
    local bucket = GetPlayerRoutingBucket(tostring(into))

    if GetPlayerRoutingBucket(tostring(who)) ~= bucket then exports.qbx_core:SetPlayerBucket(who, bucket) end
end

staff.register('goto', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    matchBucket(src, target)
    local coords = GetEntityCoords(GetPlayerPed(target))
    SetEntityCoords(GetPlayerPed(src), coords.x, coords.y, coords.z, false, false, false, false)
    staff.log(src, 'goto', target)

    return true
end)

staff.register('bring', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    matchBucket(target, src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    SetEntityCoords(GetPlayerPed(target), coords.x, coords.y, coords.z, false, false, false, false)
    staff.log(src, 'bring', target)

    return true
end)

staff.register('heal', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    exports.qbx_medical:Heal(target)
    staff.log(src, 'heal', target)

    return true
end)

staff.register('revive', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    exports.qbx_medical:Revive(target)
    staff.log(src, 'revive', target)

    return true
end)

staff.register('freeze', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    local freeze = not frozen[target]
    frozen[target] = freeze or nil
    FreezeEntityPosition(GetPlayerPed(target), freeze)
    staff.log(src, freeze and 'freeze' or 'unfreeze', target)

    return true, freeze
end)

staff.register('kill', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    TriggerClientEvent('city_staff:client:kill', target)
    staff.log(src, 'kill', target)

    return true
end)

staff.register('cuff', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end
    if GetResourceState('qbx_police') ~= 'started' then return false, 'unavailable' end

    -- qbx_police's own handler cuffs or uncuffs, whichever the player isn't
    TriggerClientEvent('police:client:GetCuffed', target, src, false)
    staff.log(src, 'cuff', target)

    return true
end)

staff.register('clothing', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    TriggerClientEvent('qb-clothing:client:openMenu', target)
    staff.log(src, 'clothing', target)

    return true
end)

staff.register('bucket', function(src, data)
    local target, reason = staff.target(src, data, { outrank = true })
    if not target then return false, reason end

    local bucket = rules.toId(data.bucket)
    if not bucket or bucket > Config.MaxBucket then return false, 'invalid' end

    exports.qbx_core:SetPlayerBucket(target, bucket)
    staff.log(src, 'bucket', target, tostring(bucket))

    return true
end)

---@param kind 'job' | 'gang'
local function setGroup(kind)
    return function(src, data)
        local target, reason = staff.target(src, data, { outrank = true })
        if not target then return false, reason end

        local groups = kind == 'job' and exports.qbx_core:GetJobs() or exports.qbx_core:GetGangs()
        local group = type(data.name) == 'string' and groups[data.name]
        local grade = rules.toId(data.grade)
        if not group or not grade or not group.grades[grade] then return false, 'invalid' end

        local success = kind == 'job' and exports.qbx_core:SetJob(target, data.name, grade) or kind == 'gang' and exports.qbx_core:SetGang(target, data.name, grade)
        if not success then return false, 'failed' end

        staff.log(src, kind == 'job' and 'setJob' or 'setGang', target, ('%s %d'):format(data.name, grade))

        return true
    end
end

staff.register('setJob', setGroup('job'))
staff.register('setGang', setGroup('gang'))

-- Only checks and logs: the staff member's client then opens the inventory, and city_inventory checks again
staff.register('inventory', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    staff.log(src, 'inventory', target)

    return true, target
end)

-- The staff member joins the target's routing bucket while watching, and goes back after
staff.register('spectate', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    if not spectating[src] then spectating[src] = GetPlayerRoutingBucket(tostring(src)) end
    matchBucket(src, target)
    staff.log(src, 'spectate', target)

    return true, { target = target, coords = GetEntityCoords(GetPlayerPed(target)) }
end)

staff.register('stopSpectate', function(src)
    local bucket = spectating[src]
    if not bucket then return true end

    spectating[src] = nil
    exports.qbx_core:SetPlayerBucket(src, bucket)

    return true
end, 'spectate')

AddEventHandler('playerDropped', function()
    local src = source
    frozen[src] = nil
    spectating[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(frozen) do
        FreezeEntityPosition(GetPlayerPed(src), false)
    end
end)
