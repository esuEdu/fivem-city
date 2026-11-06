-- Exports for city_bank only: account rows, account creation and balanced postings.
-- city_bank decides the banking rules (limits, cards, loans); this side keeps the money consistent.
local accounts = require 'server.accounts'
local ledger = require 'server.ledger'
local validation = require 'server.validation'
local average = require 'server.average'
local settings = require 'server.config'

local CALLER = 'city_bank'
local REASON = '^bank%-[%w%-]+$'
local COLUMNS = [[SELECT `id`, `number`, `type`, `owner`, `label`, `balance`, `frozen`, `goal_amount`, `goal_date`,
    `fingerprint_at` IS NOT NULL AS `fingerprint`, UNIX_TIMESTAMP(`created_at`) AS `created` FROM `economy_accounts`]]
local KINDS = { savings = true, shared = true, job = true }
local FREEZE = { debt = true, fraud = true, admin = true }

---@return boolean
local function trusted()
    if GetInvokingResource() == CALLER then return true end

    lib.print.warn(('%s used a city_bank-only export, refused'):format(tostring(GetInvokingResource())))
    return false
end

---@param row table?
---@return table?
local function shape(row)
    if not row then return end

    row.fingerprint = row.fingerprint == 1 or row.fingerprint == true
    row.display = row.number and validation.formatAccount(row.number) or nil

    return row
end

exports('BankGetAccount', function(id)
    if not trusted() or math.type(id) ~= 'integer' then return end
    accounts.wait()
    return shape(MySQL.single.await(COLUMNS .. ' WHERE `id` = ?', { id }))
end)

---Accepts '58018396' or 'LS 5801 8396'
exports('BankGetAccountByNumber', function(number)
    if not trusted() or type(number) ~= 'string' then return end
    number = number:gsub('%D', '')
    if #number ~= 8 then return end
    accounts.wait()
    return shape(MySQL.single.await(COLUMNS .. ' WHERE `number` = ?', { number }))
end)

---Personal, cash, savings and shared accounts this character owns
exports('BankGetOwnedAccounts', function(citizenid)
    if not trusted() or type(citizenid) ~= 'string' then return {} end
    accounts.wait()
    accounts.ensurePlayer(citizenid)

    local rows = MySQL.query.await(COLUMNS .. ' WHERE `owner` = ? ORDER BY `id`', { citizenid }) or {}

    for i = 1, #rows do shape(rows[i]) end

    return rows
end)

exports('BankGetAccountsByIds', function(ids)
    if not trusted() or type(ids) ~= 'table' or #ids == 0 then return {} end

    local marks, values = {}, {}

    for i = 1, math.min(#ids, 50) do
        if math.type(ids[i]) == 'integer' then
            marks[#marks + 1] = '?'
            values[#values + 1] = ids[i]
        end
    end

    if #marks == 0 then return {} end

    accounts.wait()

    local rows = MySQL.query.await(COLUMNS .. (' WHERE `id` IN (%s)'):format(table.concat(marks, ', ')), values) or {}

    for i = 1, #rows do shape(rows[i]) end

    return rows
end)

---The system accounts city_bank pays to and from (fees, loans, yield, fines)
exports('BankSystemAccount', function(name)
    if not trusted() then return end
    accounts.wait()
    return accounts.system(name)
end)

---@param kind 'savings' | 'shared' | 'job'
---@param owner string citizenid, or the job name for job accounts
---@param label string
exports('BankCreateAccount', function(kind, owner, label)
    if not trusted() or not KINDS[kind] or type(owner) ~= 'string' or type(label) ~= 'string' then return end

    accounts.wait()

    -- One savings per character and one account per job; shared accounts get a random key
    local key = kind == 'shared' and ('shared:%s'):format(lib.string.random('............'))
        or ('%s:%s'):format(kind, owner)

    for _ = 1, 10 do
        local number = ('%04d%04d'):format(math.random(1000, 9999), math.random(0, 9999))
        local affected = MySQL.update.await(
            'INSERT IGNORE INTO `economy_accounts` (`unique_key`, `number`, `type`, `owner`, `label`) VALUES (?, ?, ?, ?, ?)',
            { key, number, kind, owner, label:sub(1, 48) }
        )
        local row = MySQL.single.await(COLUMNS .. ' WHERE `unique_key` = ?', { key })

        if row then return shape(row), affected == 1 end
    end
end)

exports('BankSetLabel', function(id, label)
    if not trusted() or math.type(id) ~= 'integer' or type(label) ~= 'string' then return false end
    return MySQL.update.await('UPDATE `economy_accounts` SET `label` = ? WHERE `id` = ?', { label:sub(1, 48), id }) == 1
end)

---@param amount integer? nil clears the goal
---@param date integer? unix time
exports('BankSetGoal', function(id, amount, date)
    if not trusted() or math.type(id) ~= 'integer' then return false end
    if amount ~= nil and not validation.amount(amount, settings.maxBalance) then return false end

    return MySQL.update.await(
        'UPDATE `economy_accounts` SET `goal_amount` = ?, `goal_date` = ? WHERE `id` = ?',
        { amount or 0, math.type(date) == 'integer' and date or 0, id }
    ) == 1
end)

---@param reason 'debt' | 'fraud' | 'admin' | false false unfreezes
exports('BankSetFrozen', function(id, reason)
    if not trusted() or math.type(id) ~= 'integer' then return false end
    if reason ~= false and not FREEZE[reason] then return false end

    if reason == false then
        return MySQL.update.await('UPDATE `economy_accounts` SET `frozen` = NULL WHERE `id` = ?', { id }) == 1
    end

    return MySQL.update.await('UPDATE `economy_accounts` SET `frozen` = ? WHERE `id` = ?', { reason, id }) == 1
end)

---A balanced posting. Reasons must start with 'bank-'.
---@param entries { account: integer, delta: integer }[]
---@param reason string
---@param ref string?
---@param meta table?
exports('BankPost', function(entries, reason, ref, meta)
    if not trusted() then return false, 'not allowed' end
    if type(reason) ~= 'string' or not reason:find(REASON) then return false, 'bad reason' end

    for i = 1, type(entries) == 'table' and #entries or 0 do
        local delta = entries[i].delta
        if type(delta) ~= 'number' or math.abs(delta) > settings.maxTransaction then return false, 'amount too large' end
    end

    accounts.wait()

    -- Debts can still be paid from an account frozen for debt; that is how the freeze gets lifted
    local allowFrozen = (reason == 'bank-bill' or reason == 'bank-retention') and 'debt' or nil

    return ledger.post(entries, { reason = reason, source = CALLER, ref = ref, meta = meta, allowFrozen = allowFrozen })
end)

---Movements of one account, newest first. direction: 'in', 'out' or nil for both.
exports('BankHistory', function(id, limit, offset, direction)
    if not trusted() or math.type(id) ~= 'integer' then return {} end

    limit = math.min(math.max(math.tointeger(limit) or 25, 1), 100)
    offset = math.max(math.tointeger(offset) or 0, 0)

    local filter = direction == 'in' and ' AND `delta` > 0' or direction == 'out' and ' AND `delta` < 0' or ''

    return MySQL.query.await(
        'SELECT `delta`, `balance_after`, `reason`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `economy_ledger` WHERE `account_id` = ?'
            .. filter .. ' ORDER BY `id` DESC LIMIT ? OFFSET ?',
        { id, limit, offset }
    ) or {}
end)

exports('BankLastDay', function(id)
    if not trusted() or math.type(id) ~= 'integer' then return 0, 0 end
    return accounts.lastDay(id)
end)

---Sum of one reason into an account over the last `seconds` (e.g. the police share of fines in 30 days)
exports('BankReceived', function(id, reason, seconds)
    if not trusted() or math.type(id) ~= 'integer' or type(reason) ~= 'string' then return 0 end

    local value = MySQL.scalar.await(
        'SELECT CAST(COALESCE(SUM(`delta`), 0) AS SIGNED) FROM `economy_ledger` WHERE `account_id` = ? AND `reason` = ? AND `delta` > 0 AND `created_at` >= NOW() - INTERVAL ? SECOND',
        { id, reason, math.tointeger(seconds) or 0 }
    )

    return math.tointeger(value) or 0
end)

---Money that left an account over the last `seconds`, optionally only what one person moved (ref = their citizenid)
exports('BankOutflow', function(id, seconds, ref)
    if not trusted() or math.type(id) ~= 'integer' then return 0 end

    local query = 'SELECT CAST(COALESCE(SUM(-`delta`), 0) AS SIGNED) FROM `economy_ledger` WHERE `account_id` = ? AND `delta` < 0 AND `created_at` >= NOW() - INTERVAL ? SECOND'
    local values = { id, math.tointeger(seconds) or 0 }

    if type(ref) == 'string' then
        query = query .. ' AND `ref` = ?'
        values[3] = ref
    end

    return math.tointeger(MySQL.scalar.await(query, values)) or 0
end)

---Money in, money out and closing balance per day over the last `days` days (dashboard charts)
exports('BankDaily', function(id, days)
    if not trusted() or math.type(id) ~= 'integer' then return {} end

    days = math.min(math.max(math.tointeger(days) or 7, 1), 31)

    return MySQL.query.await([[
        SELECT DATE_FORMAT(l.`created_at`, '%Y-%m-%d') AS `day`,
               CAST(COALESCE(SUM(CASE WHEN l.`delta` > 0 THEN l.`delta` END), 0) AS SIGNED) AS `income`,
               CAST(COALESCE(SUM(CASE WHEN l.`delta` < 0 THEN -l.`delta` END), 0) AS SIGNED) AS `expenses`,
               CAST(SUBSTRING_INDEX(GROUP_CONCAT(l.`balance_after` ORDER BY l.`id` DESC), ',', 1) AS SIGNED) AS `close`
        FROM `economy_ledger` l
        WHERE l.`account_id` = ? AND l.`created_at` >= CURDATE() - INTERVAL ? DAY
        GROUP BY `day` ORDER BY `day`
    ]], { id, days - 1 }) or {}
end)

---Time-weighted average balance over the last `seconds`
exports('BankAverageBalance', function(id, seconds)
    if not trusted() or math.type(id) ~= 'integer' or math.type(seconds) ~= 'integer' then return 0 end

    local now = os.time()
    local from = now - seconds
    local before = MySQL.scalar.await(
        'SELECT `balance_after` FROM `economy_ledger` WHERE `account_id` = ? AND `created_at` < FROM_UNIXTIME(?) ORDER BY `id` DESC LIMIT 1',
        { id, from }
    )
    local rows = MySQL.query.await(
        'SELECT `balance_after` AS `balance`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `economy_ledger` WHERE `account_id` = ? AND `created_at` >= FROM_UNIXTIME(?) ORDER BY `id`',
        { id, from }
    ) or {}

    return average.balance(math.tointeger(before) or 0, rows, from, now)
end)
