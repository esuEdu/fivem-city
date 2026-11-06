-- The only code that changes balances. Every change is a balanced posting (double entry) written in one transaction,
-- with the accounts locked in memory so two writes on the same account never interleave.
local validation = require 'server.validation'
local settings = require 'server.config'

local ledger = {}

local locks = {}

local UPDATE_QUERY = 'UPDATE `economy_accounts` SET `balance` = `balance` + ? WHERE `id` = ?'
local INSERT_QUERY = [[
    INSERT INTO `economy_ledger` (`tx_id`, `account_id`, `delta`, `balance_after`, `reason`, `source`, `ref`, `meta`)
    SELECT ?, `id`, ?, `balance`, ?, ?, ?, ? FROM `economy_accounts` WHERE `id` = ?
]]

---@param ids integer[]
---@return boolean
local function acquire(ids)
    local deadline = os.time() + settings.lockTimeout

    while true do
        local free = true

        for i = 1, #ids do
            if locks[ids[i]] then
                free = false
                break
            end
        end

        -- Lua runs one thread at a time: nothing can take the lock between this check and the assignment
        if free then
            for i = 1, #ids do locks[ids[i]] = true end
            return true
        end

        if os.time() >= deadline then return false end

        Wait(0)
    end
end

---@param ids integer[]
local function release(ids)
    for i = 1, #ids do locks[ids[i]] = nil end
end

---@param ids integer[]
---@return table<integer, { type: string, balance: integer, frozen: string? }>
local function loadAccounts(ids)
    local marks = {}

    for i = 1, #ids do marks[i] = '?' end

    local rows = MySQL.query.await(
        ('SELECT `id`, `type`, `owner`, `balance`, `frozen` FROM `economy_accounts` WHERE `id` IN (%s)'):format(table.concat(marks, ', ')),
        ids
    ) or {}

    local byId = {}

    for i = 1, #rows do byId[rows[i].id] = rows[i] end

    return byId
end

---@param requestId string
---@return boolean fresh false when this request was already handled
local function claimRequest(requestId)
    local affected = MySQL.update.await('INSERT IGNORE INTO `economy_requests` (`request_id`) VALUES (?)', { requestId })

    return affected == 1
end

---Called after every committed posting with the accounts it touched (set by main.lua: mirror sync, credit event)
---@type fun(accounts: table<integer, table>, entries: table[], info: table)?
ledger.onPosted = nil

---Applies a balanced posting.
---@param entries { account: integer, delta: integer }[]
---@param info { reason: string, source: string, ref?: string, meta?: table, requestId?: string, skipMirror?: boolean }
---@return boolean ok
---@return string txIdOrError
---@return table<integer, integer>? balances new balance of each account
function ledger.post(entries, info)
    local ok, why = validation.entries(entries)

    if not ok then return false, why end
    if type(info.reason) ~= 'string' or type(info.source) ~= 'string' then return false, 'missing reason' end

    local ids = {}

    for i = 1, #entries do ids[i] = entries[i].account end

    if not acquire(ids) then return false, 'account busy' end

    local accounts = loadAccounts(ids)
    local balances = {}

    for i = 1, #entries do
        local entry = entries[i]
        local account = accounts[entry.account]

        if not account then
            release(ids)
            return false, 'unknown account'
        end

        local isSystem = account.type == 'system'

        -- A frozen account still receives money, it just can't send it
        if account.frozen and entry.delta < 0 and not (info.allowFrozen and account.frozen == info.allowFrozen) then
            release(ids)
            return false, 'account frozen'
        end

        local fits, reason = validation.fits(account.balance, entry.delta, isSystem, settings.maxBalance)

        if not fits then
            release(ids)
            return false, reason
        end

        balances[entry.account] = account.balance + entry.delta
    end

    if info.requestId and not claimRequest(info.requestId) then
        release(ids)
        return false, 'duplicate request'
    end

    local txId = lib.string.random('................'):upper()
    -- Never nil: a nil inside the parameter list would shift every value after it
    local ref = type(info.ref) == 'string' and info.ref:sub(1, 64) or ''
    local meta = info.meta and json.encode(info.meta) or ''
    local queries = {}

    for i = 1, #entries do
        local entry = entries[i]

        queries[#queries + 1] = { query = UPDATE_QUERY, values = { entry.delta, entry.account } }
        queries[#queries + 1] = {
            query = INSERT_QUERY,
            values = { txId, entry.delta, info.reason, info.source, ref, meta, entry.account },
        }
    end

    local committed = MySQL.transaction.await(queries)

    release(ids)

    if not committed then
        if info.requestId then MySQL.update.await('DELETE FROM `economy_requests` WHERE `request_id` = ?', { info.requestId }) end
        lib.print.error(('Ledger transaction failed (%s from %s)'):format(info.reason, info.source))
        return false, 'database error'
    end

    if ledger.onPosted then
        for id, balance in pairs(balances) do accounts[id].balance = balance end

        local ok, err = pcall(ledger.onPosted, accounts, entries, info)

        if not ok then lib.print.error(('After-posting hook failed: %s'):format(err)) end
    end

    return true, txId, balances
end

return ledger
