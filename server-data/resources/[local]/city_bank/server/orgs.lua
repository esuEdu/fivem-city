-- Gang (organization) accounts for the faction apps: balance, member deposits and leader withdrawals, for the
-- resources in settings.orgs.resources. Who in the gang may deposit or withdraw is the calling resource's check;
-- this side keeps every move between the member's personal account and the gang's account on the ledger.
local money = require 'server.money'
local settings = require 'server.config'

---@param resource string?
---@return boolean
local function allowed(resource)
    if resource and settings.orgs.resources[resource] then return true end

    lib.print.warn(('%s used a city_bank org export, refused'):format(tostring(resource)))
    return false
end

---@param gang string
---@param label string?
---@return table?
local function orgAccount(gang, label)
    local account = exports.city_economy:BankCreateAccount('gang', gang, type(label) == 'string' and label or gang)

    return type(account) == 'table' and account or nil
end

---@param gang unknown
---@param amount unknown
---@return boolean
local function validMove(gang, amount)
    return type(gang) == 'string' and math.type(amount) == 'integer' and amount > 0 and amount <= settings.orgs.moveMax
end

---@param src unknown
---@return table? personal
---@return string? citizenid
local function personalAccount(src)
    local player = math.type(src) == 'integer' and exports.qbx_core:GetPlayer(src)
    if not player then return end

    local personal = money.playerAccounts(player.PlayerData.citizenid)

    return personal, player.PlayerData.citizenid
end

---The balance of a gang's account (created on first use)
---@param gang string
---@param label string? account label on first use
---@return integer?
exports('OrgBalance', function(gang, label)
    if not allowed(GetInvokingResource()) or type(gang) ~= 'string' then return end

    local account = orgAccount(gang, label)

    return account and account.balance
end)

---Moves money from a member's personal account into the gang's account
---@param src integer the member
---@param gang string
---@param amount integer
---@return boolean ok
---@return string? error 'insufficient' | 'frozen' | 'failed'
exports('OrgDeposit', function(src, gang, amount)
    if not allowed(GetInvokingResource()) or not validMove(gang, amount) then return false, 'failed' end

    local personal, citizenid = personalAccount(src)
    local account = orgAccount(gang)
    if not personal or not account then return false, 'failed' end

    local ok, err = money.move(personal.id, account.id, amount, 'bank-org-deposit', citizenid, { gang = gang })

    if ok then return true end

    return false, err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed'
end)

---Moves money from the gang's account to a member's personal account. The caller checks the member may (leader).
---@param src integer the member
---@param gang string
---@param amount integer
---@return boolean ok
---@return string? error 'insufficient' | 'frozen' | 'failed'
exports('OrgWithdraw', function(src, gang, amount)
    if not allowed(GetInvokingResource()) or not validMove(gang, amount) then return false, 'failed' end

    local personal, citizenid = personalAccount(src)
    local account = orgAccount(gang)
    if not personal or not account then return false, 'failed' end

    local ok, err = money.move(account.id, personal.id, amount, 'bank-org-withdraw', citizenid, { gang = gang })

    if ok then return true end

    return false, err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed'
end)
