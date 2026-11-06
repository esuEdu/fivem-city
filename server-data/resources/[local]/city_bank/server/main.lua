-- Opening the panel at a branch, the first-visit fingerprint, the dashboard and the history tab.
-- The client only says which branch it is at; who the player is comes from source, and the server checks they really
-- stand at that banker before showing anything.
lib.locale()

local access = require 'server.access'
local accounts = require 'server.accounts'
local profile = require 'server.profile'
local schema = require 'server.schema'

CreateThread(function()
    schema.create()
    access.loadBankers()
end)

---@param src integer
---@param player table
---@return table
local function dashboard(src, player)
    local citizenid = player.PlayerData.citizenid
    local overview = exports.city_economy:GetAccountOverview(citizenid)

    if not overview then return { ok = false, error = 'failed' } end

    local tier, score = profile.tier(citizenid)
    local debt = MySQL.single.await(
        [[SELECT CAST(COALESCE(SUM(`amount` - `paid`), 0) AS SIGNED) AS `total`, COUNT(*) AS `count` FROM `bank_bills` WHERE `citizenid` = ? AND `status` IN ('pending', 'overdue')]],
        { citizenid }
    )
    local loan = MySQL.single.await(
        [[SELECT CAST(COALESCE(SUM(`total` - `paid_total`), 0) AS SIGNED) AS `left` FROM `bank_loans` WHERE `citizenid` = ? AND `status` = 'active']],
        { citizenid }
    )

    overview.ok = true
    overview.firstname = player.PlayerData.charinfo.firstname
    overview.score = score
    overview.tier = tier.label
    overview.billsTotal = debt and debt.total or 0
    overview.billsCount = debt and debt.count or 0
    overview.loanLeft = loan and loan.left or 0
    overview.staff = access.isStaff(src, citizenid)
    overview.admin = access.isAdmin(src)

    return overview
end

-- Opening the panel. Before the first fingerprint only the name is sent: no balance, no history.
lib.callback.register('city_bank:open', function(source, branchId)
    local src = source

    if access.throttled(src, 'open') then return { ok = false, error = 'busy' } end

    schema.wait()

    branchId = access.int(branchId)

    local branch = branchId and Config.Branches[branchId]
    local player = exports.qbx_core:GetPlayer(src)

    if not branch or not player then
        exports.city_economy:Flag(src, 'bank_bad_branch', 3, { branch = tostring(branchId) })
        return { ok = false, error = 'far' }
    end

    if not access.near(src, branch.coords.xyz, Config.MaxDistance) then return { ok = false, error = 'far' } end

    access.openSession(src, branchId)

    if not exports.city_economy:HasFingerprint(player.PlayerData.citizenid) then
        return { ok = true, fingerprint = false, firstname = player.PlayerData.charinfo.firstname }
    end

    return dashboard(src, player)
end)

lib.callback.register('city_bank:registerFingerprint', function(source)
    local src = source

    if access.throttled(src, 'fingerprint') then return { ok = false, error = 'busy' } end

    local player = access.atBranch(src)

    if not player then return { ok = false, error = 'far' } end

    exports.city_economy:RegisterFingerprint(player.PlayerData.citizenid)

    return dashboard(src, player)
end)

lib.callback.register('city_bank:close', function(source)
    access.closeSession(source)
    return true
end)

access.panel('dashboard', function(src, player)
    return dashboard(src, player)
end)

---Full history of one account the player can view, paged, optionally only money in or out
access.panel('history', function(_, player, _, accountId, page, direction)
    accountId = access.int(accountId)
    page = access.int(page) or 0

    local account = accountId and exports.city_economy:BankGetAccount(accountId)
    local perms = accounts.perms(player, account)

    if not perms or page < 0 or page > 200 then return { ok = false, error = 'no_permission' } end

    direction = (direction == 'in' or direction == 'out') and direction or nil

    return { ok = true, entries = exports.city_economy:BankHistory(account.id, 25, page * 25, direction) }
end)
