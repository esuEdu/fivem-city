-- Transfers tab: instant transfers by phone number or account number, and scheduled transfers (BANCO_DESIGN.md 9, 13.5)
local access = require 'server.access'
local accounts = require 'server.accounts'
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local transfers = {}

local function fail(code) return { ok = false, error = code } end

---Finds who a key points to: an account number, or a phone number (their personal account)
---@param key unknown
---@return table? account
---@return string? name masked receiver name
local function resolve(key)
    if type(key) ~= 'string' or #key > 20 then return end

    local digits = key:gsub('%D', '')
    local account = #digits == 8 and exports.city_economy:BankGetAccountByNumber(digits)

    if not account and #digits >= 6 then
        local row = MySQL.single.await(
            [[SELECT `citizenid` FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.phone')) = ? LIMIT 1]],
            { digits }
        )

        account = row and money.owned(row.citizenid, 'personal')
    end

    if not account or account.type == 'cash' or account.type == 'system' then return end

    if account.type == 'personal' then
        local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { account.owner })
        local info = row and json.decode(row.charinfo) or {}

        return account, rules.maskName(info.firstname, info.lastname)
    end

    return account, account.label
end

---How much this account may still send today under the transfer rules
---@param citizenid string
---@param account table
---@param amount integer
---@return string? error code when it isn't allowed
function transfers.check(citizenid, account, amount)
    local pix = settings.pix

    if amount > pix.perTx then return 'pix_tx_limit' end

    local sentToday = exports.city_economy:BankOutflow(account.id, 86400, citizenid)
    local dayLimit = pix.perDay

    if os.time() - (account.created or 0) < pix.newAccountSeconds then dayLimit = pix.newAccountDay end

    local restrictions = profile.restrictions(citizenid)

    if restrictions.pixDay then dayLimit = math.min(dayLimit, restrictions.pixDay) end
    if sentToday + amount > dayLimit then return 'pix_day_limit' end

    if rules.inWindow(tonumber(os.date('%H')), pix.nightFrom, pix.nightTo) then
        local sentTonight = exports.city_economy:BankOutflow(account.id, 8 * 3600, citizenid)

        if sentTonight + amount > pix.nightLimit then return 'pix_night_limit' end
    end
end

---@param player table
---@param fromId unknown
---@return table? account
---@return integer? memberRoom
local function sendingAccount(player, fromId)
    fromId = access.int(fromId)

    local account = fromId and exports.city_economy:BankGetAccount(fromId)
    local perms, dailyLimit = accounts.perms(player, account)

    if not perms or not perms.transfer then return end

    return account, accounts.memberRoom(account, player.PlayerData.citizenid, dailyLimit)
end

access.panel('lookup', function(_, _, _, key)
    local account, name = resolve(key)

    if not account then return fail('no_account') end

    return { ok = true, name = name, number = account.display }
end)

access.panel('send', function(_, player, citizenid, fromId, key, amount, reference)
    amount = access.int(amount)

    if not amount or amount <= 0 then return fail('bad_amount') end

    local from, room = sendingAccount(player, fromId)
    local to, name = resolve(key)

    if not from then return fail('no_permission') end
    if not to then return fail('no_account') end
    if to.id == from.id then return fail('same_account') end
    if room and amount > room then return fail('member_limit') end

    local blocked = transfers.check(citizenid, from, amount)

    if blocked then return fail(blocked) end

    local meta = { to = to.display, note = type(reference) == 'string' and reference:sub(1, 60) or nil }
    local ok, err = money.move(from.id, to.id, amount, 'bank-pix', citizenid, meta)

    if not ok then return fail(err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed') end

    if to.owner then money.notify(to.owner, locale('notify_received', amount)) end

    return { ok = true, name = name }
end)

access.panel('scheduled', function(_, _, citizenid)
    local rows = MySQL.query.await(
        'SELECT s.`id`, s.`amount`, s.`frequency`, s.`next_run`, s.`status`, s.`reference`, a.`number` AS `to_number` FROM `bank_scheduled` s LEFT JOIN `economy_accounts` a ON a.`id` = s.`to_account` WHERE s.`citizenid` = ? ORDER BY s.`id`',
        { citizenid }
    ) or {}

    local pix = settings.pix

    return {
        ok = true, scheduled = rows,
        limits = { perTx = pix.perTx, perDay = pix.perDay, night = pix.nightLimit, nightFrom = pix.nightFrom, nightTo = pix.nightTo },
    }
end)

access.panel('schedule', function(_, player, citizenid, fromId, key, amount, frequency, reference)
    amount = access.int(amount)

    if not amount or amount <= 0 or amount > settings.pix.perTx then return fail('bad_amount') end
    if not settings.scheduled[frequency] or type(settings.scheduled[frequency]) ~= 'number' then return fail('bad_frequency') end

    local from = sendingAccount(player, fromId)
    local to = resolve(key)

    if not from then return fail('no_permission') end
    -- Player to player only for now (BANCO_DESIGN.md 9)
    if not to or to.type ~= 'personal' or to.id == from.id then return fail('no_account') end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `bank_scheduled` WHERE `citizenid` = ?', { citizenid })

    if (tonumber(count) or 0) >= settings.scheduled.maxPerPlayer then return fail('schedule_limit') end

    MySQL.insert.await(
        'INSERT INTO `bank_scheduled` (`citizenid`, `from_account`, `to_account`, `amount`, `frequency`, `next_run`, `reference`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, from.id, to.id, amount, frequency, os.time() + settings.scheduled[frequency],
            type(reference) == 'string' and reference:sub(1, 60) or '' }
    )

    return { ok = true }
end)

access.panel('scheduleState', function(_, _, citizenid, id, action)
    id = access.int(id)

    if not id then return fail('bad_request') end

    if action == 'delete' then
        MySQL.update.await('DELETE FROM `bank_scheduled` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
    elseif action == 'pause' or action == 'resume' then
        MySQL.update.await(
            'UPDATE `bank_scheduled` SET `status` = ? WHERE `id` = ? AND `citizenid` = ?',
            { action == 'pause' and 'paused' or 'active', id, citizenid }
        )
    else
        return fail('bad_request')
    end

    return { ok = true }
end)

---Runs scheduled transfers that are due (called by the scheduler). A failed run waits for the next cycle.
function transfers.runDue()
    local now = os.time()
    local due = MySQL.query.await(
        [[SELECT * FROM `bank_scheduled` WHERE `status` = 'active' AND `next_run` <= ? LIMIT 100]],
        { now }
    ) or {}

    for i = 1, #due do
        local row = due[i]
        local from = exports.city_economy:BankGetAccount(row.from_account)
        local blocked = from and transfers.check(row.citizenid, from, row.amount)
        local ok = from and not blocked and money.move(row.from_account, row.to_account, row.amount, 'bank-scheduled', row.citizenid, { scheduled = row.id })

        MySQL.update.await('UPDATE `bank_scheduled` SET `next_run` = ? WHERE `id` = ?', { now + settings.scheduled[row.frequency], row.id })

        if not ok then money.notify(row.citizenid, locale('notify_scheduled_failed', row.amount), 'error') end
    end
end

return transfers
