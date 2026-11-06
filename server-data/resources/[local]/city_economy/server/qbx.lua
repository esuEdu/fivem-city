-- qbx_core's AddMoney / RemoveMoney / SetMoney land here (scripts/patches/qbx_core.patch).
-- Every script that pays or charges through qbx goes through the allowlist and the ledger.
local accounts = require 'server.accounts'
local allowlistLib = require 'server.allowlist'
local ledger = require 'server.ledger'
local validation = require 'server.validation'
local settings = require 'server.config'

local allowlist = allowlistLib.new(settings.sources)

local ACCOUNT_KIND = { bank = 'personal', cash = 'cash' }

---@param citizenid string
---@param moneyType 'cash' | 'bank'
---@param action 'add' | 'remove' | 'set'
---@param amount integer
---@param reason string
---@param resource string the script that asked qbx_core
---@return boolean ok
---@return integer? balance the new balance qbx_core should mirror
local function qbxMoneyChange(citizenid, moneyType, action, amount, reason, resource)
    -- Only qbx_core itself may call this; it passes the real calling resource along
    if GetInvokingResource() ~= 'qbx_core' then
        lib.print.warn(('QbxMoneyChange called by %s, refused'):format(tostring(GetInvokingResource())))
        return false
    end

    local kind = ACCOUNT_KIND[moneyType]

    if not kind or type(citizenid) ~= 'string' or type(reason) ~= 'string' or type(resource) ~= 'string' then
        return false
    end

    local wanted = action == 'set' and (amount == 0 and 0 or validation.amount(amount, settings.maxBalance))
        or validation.amount(amount, settings.maxTransaction)

    if not wanted then return false end

    accounts.wait()

    -- Creates the accounts if this is the first money the character ever touches
    local personal, cash = accounts.ensurePlayer(citizenid)
    local account = kind == 'personal' and personal or cash

    if not account then return false end

    local delta = action == 'add' and wanted or action == 'remove' and -wanted or wanted - account.balance

    if delta == 0 then return true, account.balance end

    local direction = delta > 0 and 'credit' or 'debit'
    local size = math.abs(delta)
    local now = os.time()
    local allowed, why = allowlistLib.check(allowlist, resource, reason, direction, citizenid, size, now)

    if not allowed then
        lib.print.warn(('Refused %s of $%d (%s) for %s from %s: %s'):format(direction, size, reason, citizenid, resource, why))
        return false
    end

    local other = accounts.system(direction == 'credit' and 'WORLD_MINT' or 'WORLD_SINK')
    local ok, result, balances = ledger.post({
        { account = other, delta = -delta },
        { account = account.id, delta = delta },
    }, { reason = reason, source = resource, ref = citizenid })

    if not ok then
        lib.print.warn(('Ledger refused %s of $%d (%s) for %s from %s: %s'):format(direction, size, reason, citizenid, resource, result))
        return false
    end

    if direction == 'credit' then allowlistLib.record(allowlist, resource, reason, citizenid, size, now) end

    return true, balances[account.id]
end

exports('QbxMoneyChange', qbxMoneyChange)
