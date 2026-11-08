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

local MONEY_ACCOUNTS = { cash = true, bank = true }
local REASON_LENGTH = { min = 3, max = 100 }

-- Give money: cash or bank, with a reason. It goes through qbx_core into city_economy as 'staff-grant', which caps it
-- per character per hour; the reason only goes to the staff log.
staff.register('giveMoney', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    local account = data.account
    local amount = type(data.amount) == 'number' and math.tointeger(data.amount)
    if not MONEY_ACCOUNTS[account] or not amount or amount < 1 or amount > Config.MaxGiveMoney then return false, 'invalid' end

    local why = type(data.reason) == 'string' and data.reason:gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #why < REASON_LENGTH.min then return false, 'no_reason' end
    why = why:sub(1, REASON_LENGTH.max)

    if not exports.qbx_core:AddMoney(target, account, amount, 'staff-grant') then return false, 'money_refused' end

    staff.log(src, 'giveMoney', target, ('$%d %s: %s'):format(amount, account, why))

    return true
end)
