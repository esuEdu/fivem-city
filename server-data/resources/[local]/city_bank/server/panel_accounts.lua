-- Accounts tab: savings, the shared account and its members, job accounts, goals and moving money between them
local access = require 'server.access'
local accounts = require 'server.accounts'
local money = require 'server.money'
local settings = require 'server.config'

local function fail(code) return { ok = false, error = code } end

---Account rows as the page needs them
local function present(list)
    local out = {}

    for i = 1, #list do
        local a = list[i]
        out[i] = {
            id = a.id, type = a.type, label = a.label, number = a.display, balance = a.balance, frozen = a.frozen,
            goal = (a.goal_amount or 0) > 0 and a.goal_amount or nil, goalDate = (a.goal_date or 0) > 0 and a.goal_date or nil,
            role = a.role, perms = a.perms,
        }
    end

    return out
end

---@param player table
---@param accountId unknown
---@param perm string
---@return table? account
---@return table? perms
---@return integer? dailyLimit
local function withPerm(player, accountId, perm)
    accountId = access.int(accountId)

    local account = accountId and exports.city_economy:BankGetAccount(accountId)
    local perms, dailyLimit = accounts.perms(player, account)

    if not perms or not perms[perm] then return end

    return account, perms, dailyLimit
end

access.panel('accounts', function(_, player, citizenid)
    local member = accounts.membership(citizenid)
    local pending = member and member.status == 'pending' and exports.city_economy:BankGetAccount(member.account_id)

    return {
        ok = true,
        accounts = present(accounts.list(player)),
        canShare = accounts.canShare(citizenid),
        pendingJoin = pending and pending.display or nil,
        hasSavings = money.owned(citizenid, 'savings') ~= nil,
    }
end)

access.panel('createSavings', function(_, _, citizenid)
    local account = exports.city_economy:BankCreateAccount('savings', citizenid, 'Savings')

    return account and { ok = true } or fail('failed')
end)

access.panel('createShared', function(_, _, citizenid, label)
    if type(label) ~= 'string' or #label < 2 or #label > 32 then return fail('bad_label') end
    if not accounts.canShare(citizenid) then return fail('share_limit') end

    local account = exports.city_economy:BankCreateAccount('shared', citizenid, label)

    return account and { ok = true } or fail('failed')
end)

access.panel('requestJoin', function(_, player, citizenid, number)
    local account = type(number) == 'string' and exports.city_economy:BankGetAccountByNumber(number)

    if not account or account.type ~= 'shared' then return fail('no_account') end
    if account.owner == citizenid then return fail('own_account') end
    if not accounts.canShare(citizenid) then return fail('share_limit') end

    MySQL.insert.await(
        'INSERT IGNORE INTO `bank_members` (`account_id`, `citizenid`, `name`, `daily_limit`, `status`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)',
        { account.id, citizenid, access.name(player), settings.shared.memberDailyLimit, 'pending', os.time() }
    )

    money.notify(account.owner, locale('notify_join_request', access.name(player)))

    return { ok = true }
end)

access.panel('members', function(_, player, _, accountId)
    local account = withPerm(player, accountId, 'members')

    if not account then return fail('no_permission') end

    local rows = MySQL.query.await(
        'SELECT `citizenid`, `name`, `perms`, `daily_limit`, `status` FROM `bank_members` WHERE `account_id` = ? ORDER BY `created_at`',
        { account.id }
    ) or {}

    return { ok = true, members = rows, kind = account.type }
end)

---Approve or deny a pending request
access.panel('decideMember', function(_, player, _, accountId, memberId, approve)
    local account = withPerm(player, accountId, 'members')

    if not account or account.type ~= 'shared' or type(memberId) ~= 'string' then return fail('no_permission') end

    if approve == true then
        if not accounts.canShare(memberId) and not MySQL.scalar.await(
            [[SELECT 1 FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'pending']], { account.id, memberId }
        ) then
            return fail('share_limit')
        end

        MySQL.update.await(
            [[UPDATE `bank_members` SET `status` = 'active' WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'pending']],
            { account.id, memberId }
        )
        money.notify(memberId, locale('notify_join_approved', account.label))
    else
        MySQL.update.await([[DELETE FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'pending']], { account.id, memberId })
    end

    return { ok = true }
end)

access.panel('setMember', function(_, player, _, accountId, memberId, perms, dailyLimit)
    local account = withPerm(player, accountId, 'members')
    dailyLimit = access.int(dailyLimit)

    if not account or type(memberId) ~= 'string' then return fail('no_permission') end
    if not dailyLimit or dailyLimit < 0 or dailyLimit > settings.pix.perDay then return fail('bad_amount') end

    -- Job account viewers can only ever view
    local clean = account.type == 'job' and 'view' or accounts.cleanPerms(perms)

    MySQL.update.await(
        [[UPDATE `bank_members` SET `perms` = ?, `daily_limit` = ? WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'active']],
        { clean, dailyLimit, account.id, memberId }
    )

    return { ok = true }
end)

access.panel('removeMember', function(_, player, _, accountId, memberId)
    local account = withPerm(player, accountId, 'members')

    if not account or type(memberId) ~= 'string' then return fail('no_permission') end

    MySQL.update.await('DELETE FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ?', { account.id, memberId })
    -- Their cards on this account stop working at once
    MySQL.update.await(
        [[UPDATE `bank_cards` SET `status` = 'blocked' WHERE `account_id` = ? AND `holder` = ? AND `status` IN ('active', 'locked')]],
        { account.id, memberId }
    )

    return { ok = true }
end)

---A job boss gives a nearby player view access to the job account
access.panel('addViewer', function(src, player, _, accountId, targetId)
    local account = withPerm(player, accountId, 'members')
    targetId = access.int(targetId)

    if not account or account.type ~= 'job' then return fail('no_permission') end

    local target = targetId and exports.qbx_core:GetPlayer(targetId)

    if not target or not access.near(src, GetEntityCoords(GetPlayerPed(targetId)), 5.0) then return fail('no_player') end

    MySQL.insert.await(
        [[INSERT IGNORE INTO `bank_members` (`account_id`, `citizenid`, `name`, `perms`, `status`, `created_at`) VALUES (?, ?, ?, 'view', 'active', ?)]],
        { account.id, target.PlayerData.citizenid, access.name(target), os.time() }
    )

    return { ok = true }
end)

access.panel('leaveShared', function(_, _, citizenid)
    local member = accounts.membership(citizenid)

    if not member then return fail('no_account') end

    MySQL.update.await('DELETE FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ?', { member.account_id, citizenid })
    MySQL.update.await(
        [[UPDATE `bank_cards` SET `status` = 'blocked' WHERE `account_id` = ? AND `holder` = ? AND `status` IN ('active', 'locked')]],
        { member.account_id, citizenid }
    )

    return { ok = true }
end)

---Moves money between two accounts the player can use (both must allow it)
access.panel('move', function(_, player, citizenid, fromId, toId, amount)
    amount = access.int(amount)

    if not amount or amount <= 0 or amount > settings.teller.maxOperation then return fail('bad_amount') end

    local from, _, dailyLimit = withPerm(player, fromId, 'withdraw')
    local to = withPerm(player, toId, 'deposit')

    if not from or not to or from.id == to.id then return fail('no_permission') end

    local room = accounts.memberRoom(from, citizenid, dailyLimit)

    if room and amount > room then return fail('member_limit') end

    if from.type == 'job' and exports.city_economy:BankOutflow(from.id, 3600) + amount > settings.jobs.withdrawPerHour then
        return fail('job_limit')
    end

    local ok, err = money.move(from.id, to.id, amount, 'bank-move', citizenid)

    return ok and { ok = true } or fail(err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed')
end)

access.panel('setGoal', function(_, player, _, accountId, amount, date)
    local account = withPerm(player, accountId, 'members')
    amount = access.int(amount)
    date = access.int(date)

    if not account then return fail('no_permission') end

    if not amount or amount == 0 then
        exports.city_economy:BankSetGoal(account.id, nil, nil)
    elseif amount < 0 or not exports.city_economy:BankSetGoal(account.id, amount, date) then
        return fail('bad_amount')
    end

    return { ok = true }
end)

access.panel('rename', function(_, player, _, accountId, label)
    local account = withPerm(player, accountId, 'members')

    if not account or account.type == 'personal' then return fail('no_permission') end
    if type(label) ~= 'string' or #label < 2 or #label > 32 then return fail('bad_label') end

    exports.city_economy:BankSetLabel(account.id, label)

    return { ok = true }
end)
