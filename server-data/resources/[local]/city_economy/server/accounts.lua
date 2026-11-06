local schema = require 'server.schema'
local ledger = require 'server.ledger'
local settings = require 'server.config'

local accounts = {}

local systemIds = {}
local ready = promise.new()

local SELECT_COLUMNS = 'SELECT `id`, `number`, `type`, `owner`, `label`, `balance`, `frozen`, `fingerprint_at` FROM `economy_accounts`'

function accounts.init()
    schema.create()

    local rows = MySQL.query.await(SELECT_COLUMNS .. ' WHERE `type` = ?', { 'system' }) or {}

    for i = 1, #rows do systemIds[rows[i].label] = rows[i].id end

    for i = 1, #schema.SYSTEM_ACCOUNTS do
        assert(systemIds[schema.SYSTEM_ACCOUNTS[i]], ('System account %s is missing'):format(schema.SYSTEM_ACCOUNTS[i]))
    end

    ready:resolve()
end

---Blocks until the tables exist; every entry point calls this first
function accounts.wait()
    Citizen.Await(ready)
end

---@param name 'WORLD_MINT' | 'WORLD_SINK' | 'GOV_TREASURY' | 'BANK_RESERVE'
---@return integer
function accounts.system(name)
    return systemIds[name]
end

---@param kind 'personal' | 'cash'
---@param citizenid string
---@return table?
function accounts.get(kind, citizenid)
    return MySQL.single.await(SELECT_COLUMNS .. ' WHERE `unique_key` = ?', { ('%s:%s'):format(kind, citizenid) })
end

---@return string 8 random digits
local function randomNumber()
    return ('%04d%04d'):format(math.random(1000, 9999), math.random(0, 9999))
end

---Creates the account if it doesn't exist. Personal accounts get a random (never sequential) number.
---@param kind 'personal' | 'cash'
---@param citizenid string
---@param label string
---@return table? account
---@return boolean created
local function ensure(kind, citizenid, label)
    local existing = accounts.get(kind, citizenid)

    if existing then return existing, false end

    local key = ('%s:%s'):format(kind, citizenid)

    for _ = 1, 10 do
        -- A nil inside the parameter list would shift the values after it, so cash accounts use their own query
        local affected

        if kind == 'personal' then
            affected = MySQL.update.await(
                'INSERT IGNORE INTO `economy_accounts` (`unique_key`, `number`, `type`, `owner`, `label`) VALUES (?, ?, ?, ?, ?)',
                { key, randomNumber(), kind, citizenid, label }
            )
        else
            affected = MySQL.update.await(
                'INSERT IGNORE INTO `economy_accounts` (`unique_key`, `type`, `owner`, `label`) VALUES (?, ?, ?, ?)',
                { key, kind, citizenid, label }
            )
        end

        if affected == 1 then return accounts.get(kind, citizenid), true end

        -- Either the number was taken (try another) or another call created the account first
        existing = accounts.get(kind, citizenid)

        if existing then return existing, false end
    end

    lib.print.error(('Could not create the %s account for %s'):format(kind, citizenid))
end

---@param account table
---@param amount integer
local function grantStarting(account, amount)
    if amount <= 0 then return end

    local ok, err = ledger.post({
        { account = accounts.system('WORLD_MINT'), delta = -amount },
        { account = account.id, delta = amount },
    }, { reason = 'starting', source = 'city_economy', ref = account.owner })

    if not ok then lib.print.error(('Starting money for %s failed: %s'):format(account.owner, err)) end
end

---Makes sure a character has a personal and a cash account; a brand-new character gets the starting money.
---@param citizenid string
---@return table? personal
---@return table? cash
function accounts.ensurePlayer(citizenid)
    local personal, personalCreated = ensure('personal', citizenid, 'Personal')
    local cash, cashCreated = ensure('cash', citizenid, 'Cash')

    if not personal or not cash then return end

    if personalCreated then grantStarting(personal, settings.startingBank) end
    if cashCreated then grantStarting(cash, settings.startingCash) end

    if personalCreated or cashCreated then
        personal = accounts.get('personal', citizenid)
        cash = accounts.get('cash', citizenid)
    end

    return personal, cash
end

---@param citizenid string
---@return boolean
function accounts.registerFingerprint(citizenid)
    local affected = MySQL.update.await(
        'UPDATE `economy_accounts` SET `fingerprint_at` = CURRENT_TIMESTAMP WHERE `unique_key` = ? AND `fingerprint_at` IS NULL',
        { ('personal:%s'):format(citizenid) }
    )

    return affected == 1
end

---Last movements of one account, newest first
---@param accountId integer
---@param limit integer
---@return table[]
function accounts.history(accountId, limit)
    return MySQL.query.await(
        'SELECT `delta`, `balance_after`, `reason`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `economy_ledger` WHERE `account_id` = ? ORDER BY `id` DESC LIMIT ?',
        { accountId, limit }
    ) or {}
end

---Money in and out over the last 24 hours
---@param accountId integer
---@return integer income
---@return integer expenses
function accounts.lastDay(accountId)
    local row = MySQL.single.await([[
        SELECT CAST(COALESCE(SUM(CASE WHEN `delta` > 0 THEN `delta` END), 0) AS SIGNED) AS `income`,
               CAST(COALESCE(SUM(CASE WHEN `delta` < 0 THEN -`delta` END), 0) AS SIGNED) AS `expenses`
        FROM `economy_ledger` WHERE `account_id` = ? AND `created_at` >= NOW() - INTERVAL 1 DAY
    ]], { accountId })

    return math.tointeger(row and row.income) or 0, math.tointeger(row and row.expenses) or 0
end

return accounts
