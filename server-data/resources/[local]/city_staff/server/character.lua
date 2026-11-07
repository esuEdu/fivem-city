-- Changing a player from their page: job, gang (or firing them from either), routing bucket, armor, hunger, thirst.

local rules = require 'shared.rules'
local staff = require 'server.staff'

-- What "fire" sets: qbx_core's no-job and no-gang groups
local NO_GROUP = { job = 'unemployed', gang = 'none' }

---@param kind 'job' | 'gang'
local function setGroup(kind)
    return function(src, data)
        local target, reason = staff.target(src, data, { outrank = true })
        if not target then return false, reason end

        local name = data.fire == true and NO_GROUP[kind] or data.name
        local grade = data.fire == true and 0 or rules.toId(data.grade)
        local groups = kind == 'job' and exports.qbx_core:GetJobs() or exports.qbx_core:GetGangs()
        local group = type(name) == 'string' and groups[name]
        if not group or not grade or not group.grades[grade] then return false, 'invalid' end

        local success = kind == 'job' and exports.qbx_core:SetJob(target, name, grade) or kind == 'gang' and exports.qbx_core:SetGang(target, name, grade)
        if not success then return false, 'failed' end

        staff.log(src, kind == 'job' and 'setJob' or 'setGang', target, ('%s %d'):format(name, grade))

        return true
    end
end

staff.register('setJob', setGroup('job'))
staff.register('setGang', setGroup('gang'))

staff.register('bucket', function(src, data)
    local target, reason = staff.target(src, data, { outrank = true })
    if not target then return false, reason end

    local bucket = rules.toId(data.bucket)
    if not bucket or bucket > Config.MaxBucket then return false, 'invalid' end

    exports.qbx_core:SetPlayerBucket(target, bucket)
    staff.log(src, 'bucket', target, tostring(bucket))

    return true
end)

-- Armor, hunger and thirst, 0 to 100
staff.register('setStat', function(src, data)
    local target, reason = staff.target(src, data, { outrank = true })
    if not target then return false, reason end

    local stat = data.stat
    local value = rules.toId(data.value)
    if (stat ~= 'armor' and stat ~= 'hunger' and stat ~= 'thirst') or not value or value > 100 then return false, 'invalid' end

    if stat == 'armor' then
        SetPedArmour(GetPlayerPed(target), value)
        exports.qbx_core:SetMetadata(target, 'armor', value)
    else
        exports.qbx_core:SetMetadata(target, stat, value)

        local metadata = exports.qbx_core:GetPlayer(target).PlayerData.metadata
        TriggerClientEvent('hud:client:UpdateNeeds', target, metadata.hunger, metadata.thirst)
    end

    staff.log(src, 'setStat', target, ('%s %d'):format(stat, value))

    return true
end, 'setStats')
