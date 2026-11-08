-- Purchases a business makes from its own job account (parts a mechanic fits, supplies), for the resources in
-- settings.jobPurchases. The money leaves the economy (WORLD_SINK): it pays a supplier outside the city.
local money = require 'server.money'
local settings = require 'server.config'

---@param resource string?
---@param job any
---@return boolean
local function allowed(resource, job)
    local jobs = resource and settings.jobPurchases[resource]
    if type(jobs) ~= 'table' or type(job) ~= 'string' then return false end

    for i = 1, #jobs do
        if jobs[i] == job then return true end
    end

    return false
end

---@param job string
---@return table?
local function jobAccount(job)
    local account = exports.city_economy:BankCreateAccount('job', job, job)

    return type(account) == 'table' and account or nil
end

---The balance of a job account, for the resources that buy from it
---@param job string
---@return integer?
exports('JobBalance', function(job)
    if not allowed(GetInvokingResource(), job) then return end

    local account = jobAccount(job)

    return account and account.balance
end)

---Pays for something out of a job account. Only resources in settings.jobPurchases, each only for its jobs.
---@param job string
---@param amount integer
---@param label string what was bought, shown in the account history
---@param actor string? citizenid of who bought it
---@return boolean ok
---@return string? error 'insufficient' | 'frozen' | 'failed'
exports('ChargeJob', function(job, amount, label, actor)
    local resource = GetInvokingResource()

    if not allowed(resource, job) then
        lib.print.warn(('%s tried to charge the %s account, refused'):format(tostring(resource), tostring(job)))
        return false, 'failed'
    end

    if math.type(amount) ~= 'integer' or amount <= 0 or amount > settings.jobs.purchaseMax then return false, 'failed' end
    if type(label) ~= 'string' then return false, 'failed' end

    local account = jobAccount(job)
    if not account then return false, 'failed' end

    local ok, err = money.move(account.id, money.system('WORLD_SINK'), amount, 'bank-job-purchase',
        type(actor) == 'string' and actor or resource, { label = label:sub(1, 64), by = resource })

    if ok then return true end

    return false, err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed'
end)
