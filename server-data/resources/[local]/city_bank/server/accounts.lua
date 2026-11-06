-- Which accounts a character can use and what they may do with each (BANCO_DESIGN.md 3)
local settings = require 'server.config'

local accounts = {}

local ALL = { view = true, deposit = true, withdraw = true, transfer = true, cards = true, members = true }
local PERM_NAMES = { 'view', 'deposit', 'withdraw', 'transfer', 'cards', 'members' }

accounts.PERM_NAMES = PERM_NAMES

---'view,deposit' -> { view = true, deposit = true }
local function parsePerms(text)
    local perms = {}

    for perm in tostring(text):gmatch('[^,]+') do
        if ALL[perm] then perms[perm] = true end
    end

    perms.view = true

    return perms
end

---Only known permission names, always including view
---@param list unknown
---@return string
function accounts.cleanPerms(list)
    local kept = { 'view' }

    if type(list) == 'table' then
        for _, perm in ipairs(PERM_NAMES) do
            if perm ~= 'view' and list[perm] == true then kept[#kept + 1] = perm end
        end
    end

    return table.concat(kept, ',')
end

---@param citizenid string
---@return table? membership the active or pending shared membership of this character
function accounts.membership(citizenid)
    return MySQL.single.await(
        [[SELECT m.* FROM `bank_members` m JOIN `economy_accounts` a ON a.`id` = m.`account_id` WHERE m.`citizenid` = ? AND a.`type` = 'shared']],
        { citizenid }
    )
end

---What this character may do with an account; nil = no access at all
---@param player table
---@param account table? row from city_economy
---@return table<string, boolean>? perms
---@return integer? dailyLimit for members of a shared account
function accounts.perms(player, account)
    if not account then return end

    local citizenid = player.PlayerData.citizenid

    if account.type == 'job' then
        local job = player.PlayerData.job

        if job and job.name == account.owner and job.isboss then return ALL end

        local viewer = MySQL.single.await(
            [[SELECT `perms` FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'active']],
            { account.id, citizenid }
        )

        return viewer and { view = true } or nil
    end

    if account.owner == citizenid and account.type ~= 'cash' then return ALL end

    if account.type == 'shared' then
        local member = MySQL.single.await(
            [[SELECT `perms`, `daily_limit` FROM `bank_members` WHERE `account_id` = ? AND `citizenid` = ? AND `status` = 'active']],
            { account.id, citizenid }
        )

        if member then return parsePerms(member.perms), member.daily_limit end
    end
end

---Every account this character can see, with their permissions
---@param player table
---@return table[]
function accounts.list(player)
    local citizenid = player.PlayerData.citizenid
    local owned = exports.city_economy:BankGetOwnedAccounts(citizenid)
    local list = {}

    for i = 1, #owned do
        if owned[i].type ~= 'cash' then
            owned[i].perms = ALL
            owned[i].role = 'owner'
            list[#list + 1] = owned[i]
        end
    end

    local member = accounts.membership(citizenid)

    if member and member.status == 'active' then
        local account = exports.city_economy:BankGetAccount(member.account_id)

        if account then
            account.perms = parsePerms(member.perms)
            account.role = 'member'
            list[#list + 1] = account
        end
    end

    local job = player.PlayerData.job

    -- The boss (and sub-boss grades) of a job get its account; it is created the first time one of them looks
    if job and job.name ~= 'unemployed' and job.isboss then
        local account = exports.city_economy:BankCreateAccount('job', job.name, job.label or job.name)

        if account then
            account.perms = ALL
            account.role = 'boss'
            list[#list + 1] = account
        end
    end

    local viewing = MySQL.query.await(
        [[SELECT m.`account_id` FROM `bank_members` m WHERE m.`citizenid` = ? AND m.`status` = 'active']],
        { citizenid }
    ) or {}

    for i = 1, #viewing do
        local account = exports.city_economy:BankGetAccount(viewing[i].account_id)

        if account and account.type == 'job' and not (job and job.isboss and job.name == account.owner) then
            account.perms = { view = true }
            account.role = 'viewer'
            list[#list + 1] = account
        end
    end

    return list
end

---Whether this character may still join or create a shared account (one in total, owner or member)
---@param citizenid string
---@return boolean
function accounts.canShare(citizenid)
    local owned = MySQL.scalar.await(
        [[SELECT COUNT(*) FROM `economy_accounts` WHERE `owner` = ? AND `type` = 'shared']],
        { citizenid }
    )
    local member = MySQL.scalar.await(
        [[SELECT COUNT(*) FROM `bank_members` m JOIN `economy_accounts` a ON a.`id` = m.`account_id` WHERE m.`citizenid` = ? AND a.`type` = 'shared']],
        { citizenid }
    )

    return (tonumber(owned) or 0) + (tonumber(member) or 0) < settings.shared.maxPerPlayer
end

---Money a member may still take out of a shared account today
---@param account table
---@param citizenid string
---@param dailyLimit integer?
---@return integer?
function accounts.memberRoom(account, citizenid, dailyLimit)
    if not dailyLimit then return nil end

    return math.max(0, dailyLimit - exports.city_economy:BankOutflow(account.id, 86400, citizenid))
end

return accounts
