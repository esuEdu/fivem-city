-- Server exports for our other resources. None of these is a net event; clients can't reach them.
local accounts = require 'server.accounts'
local validation = require 'server.validation'
local flags = require 'server.flags'

local HISTORY_LIMIT = 25

-- Account details are private: only these resources may read them
local READERS = { city_bank = true }

---@return boolean
local function trustedCaller()
    local caller = GetInvokingResource()

    if READERS[caller] then return true end

    lib.print.warn(('%s tried to read account details, refused'):format(tostring(caller)))
    return false
end

---Everything the bank panel shows for a character's personal account.
---@param citizenid string
---@return table?
local function getAccountOverview(citizenid)
    if not trustedCaller() or type(citizenid) ~= 'string' then return end

    accounts.wait()

    local personal, cash = accounts.ensurePlayer(citizenid)

    if not personal or not cash then return end

    local income, expenses = accounts.lastDay(personal.id)

    return {
        number = validation.formatAccount(personal.number),
        label = personal.label,
        balance = personal.balance,
        cash = cash.balance,
        frozen = personal.frozen,
        fingerprint = personal.fingerprint_at ~= nil,
        income = income,
        expenses = expenses,
        history = accounts.history(personal.id, HISTORY_LIMIT),
    }
end

exports('GetAccountOverview', getAccountOverview)

---Whether the character has registered a fingerprint at a branch (first visit)
---@param citizenid string
---@return boolean
local function hasFingerprint(citizenid)
    if not trustedCaller() or type(citizenid) ~= 'string' then return false end

    accounts.wait()

    local personal = accounts.ensurePlayer(citizenid)

    return personal ~= nil and personal.fingerprint_at ~= nil
end

exports('HasFingerprint', hasFingerprint)

---@param citizenid string
---@return boolean registered false if it already was
local function registerFingerprint(citizenid)
    if not trustedCaller() or type(citizenid) ~= 'string' then return false end

    accounts.wait()
    accounts.ensurePlayer(citizenid)

    return accounts.registerFingerprint(citizenid)
end

exports('RegisterFingerprint', registerFingerprint)

---Lets other resources report suspicious activity into the same flag table
---@param src integer
---@param kind string
---@param severity integer
---@param context table?
local function flag(src, kind, severity, context)
    if type(kind) ~= 'string' or type(severity) ~= 'number' then return end

    context = type(context) == 'table' and context or {}
    context.resource = GetInvokingResource()

    flags.add(type(src) == 'number' and src or nil, nil, kind, math.max(1, math.min(5, math.floor(severity))), context)
end

exports('Flag', flag)
