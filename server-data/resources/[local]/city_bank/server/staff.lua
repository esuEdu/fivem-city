-- Staff tab for bankers (and admins on duty): loan queue, client file, card ceilings, freezes, and (admins only)
-- the banker list. Every action is written to bank_audit with who did it.
local access = require 'server.access'
local accounts = require 'server.accounts'
local cards = require 'server.cards'
local loans = require 'server.loans'
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local function fail(code) return { ok = false, error = code } end

---Registers a staff-only panel request
local function staff(name, handler)
    access.panel(name, function(src, player, citizenid, ...)
        if not access.isStaff(src, citizenid) then
            exports.city_economy:Flag(src, 'bank_staff_denied', 3, { action = name })
            return fail('no_permission')
        end

        return handler(src, player, access.name(player), ...)
    end)
end

---Staff never act on their own money: their own loan, card or any account they can use. Trying is flagged.
---@param src integer
---@param action string
---@return table reply
local function ownBusiness(src, action)
    exports.city_economy:Flag(src, 'bank_staff_self', 3, { action = action })
    return fail('own_client')
end

staff('staffQueue', function()
    local rows = MySQL.query.await(
        [[SELECT `id`, `citizenid`, `name`, `amount`, `rate`, `total`, `installments`, `reason`, `created_at` FROM `bank_loans` WHERE `status` = 'requested' ORDER BY `id` LIMIT 50]]
    ) or {}

    for i = 1, #rows do
        local tier, score = profile.tier(rows[i].citizenid)

        rows[i].rate = tonumber(rows[i].rate)
        rows[i].score = score
        rows[i].tier = tier.label
        rows[i].overdueDays = profile.overdue(rows[i].citizenid)
    end

    return { ok = true, queue = rows }
end)

staff('staffDecide', function(src, player, actor, id, approve, note)
    id = access.int(id)

    local loan = id and MySQL.single.await([[SELECT * FROM `bank_loans` WHERE `id` = ? AND `status` = 'requested']], { id })

    if not loan then return fail('no_loan') end
    if loan.citizenid == player.PlayerData.citizenid then return ownBusiness(src, 'loan') end

    note = type(note) == 'string' and note:sub(1, 120) or ''

    MySQL.update.await('UPDATE `bank_loans` SET `decided_by` = ?, `decision` = ? WHERE `id` = ?', { actor, note, id })

    if approve == true then
        if not loans.disburse(loan) then return fail('failed') end
        money.notify(loan.citizenid, locale('notify_loan_approved', loan.amount), 'success')
    else
        MySQL.update.await([[UPDATE `bank_loans` SET `status` = 'denied' WHERE `id` = ?]], { id })
        money.notify(loan.citizenid, locale('notify_loan_denied'), 'error')
    end

    access.audit(actor, approve == true and 'loan_approve' or 'loan_deny', loan.citizenid, { loan = id, amount = loan.amount, note = note })

    return { ok = true }
end)

---Client file looked up by account number. The lookup itself is audited.
staff('staffClient', function(_, _, actor, number)
    local account = type(number) == 'string' and exports.city_economy:BankGetAccountByNumber(number)

    if not account or account.type ~= 'personal' then return fail('no_account') end

    local citizenid = account.owner
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { citizenid })
    local info = row and json.decode(row.charinfo) or {}
    local tier, score = profile.tier(citizenid)
    local owned = exports.city_economy:BankGetOwnedAccounts(citizenid)
    local cardRows = MySQL.query.await([[SELECT * FROM `bank_cards` WHERE `holder` = ? AND `status` <> 'replaced']], { citizenid }) or {}
    local cardList = {}

    for i = 1, #cardRows do
        cardList[i] = {
            id = cardRows[i].id, last4 = cardRows[i].last4, status = cardRows[i].status,
            ceilings = cards.ceilings(cardRows[i]), custom = cardRows[i].ceilings ~= nil,
        }
    end

    access.audit(actor, 'client_view', citizenid, { account = account.display })

    return {
        ok = true,
        client = {
            citizenid = citizenid, name = ('%s %s'):format(info.firstname or '?', info.lastname or '?'),
            score = score, tier = tier.label, overdueDays = profile.overdue(citizenid),
            accounts = owned, cards = cardList,
            loans = MySQL.query.await('SELECT `id`, `amount`, `status`, `paid_count`, `installments` FROM `bank_loans` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 5', { citizenid }) or {},
            bills = MySQL.query.await([[SELECT `id`, `label`, `amount`, `paid`, `status` FROM `bank_bills` WHERE `citizenid` = ? AND `status` IN ('pending', 'overdue')]], { citizenid }) or {},
            history = exports.city_economy:BankHistory(account.id, 15, 0),
        },
    }
end)

---Raises (or resets) a card's ceilings, up to a multiple of the holder's tier
staff('staffCeilings', function(src, player, actor, id, requested)
    id = access.int(id)

    local card = id and MySQL.single.await('SELECT * FROM `bank_cards` WHERE `id` = ?', { id })

    if not card then return fail('no_card') end

    -- Their own card, or a card on an account they can use (e.g. their shared account)
    if card.holder == player.PlayerData.citizenid or accounts.perms(player, exports.city_economy:BankGetAccount(card.account_id)) then
        return ownBusiness(src, 'ceilings')
    end

    if requested == false then
        MySQL.update.await('UPDATE `bank_cards` SET `ceilings` = NULL WHERE `id` = ?', { id })
        access.audit(actor, 'ceiling_reset', card.holder, { card = card.last4 })
        return { ok = true }
    end

    if type(requested) ~= 'table' then return fail('bad_request') end

    local tierCeilings = profile.tierCeilings((profile.tier(card.holder)))
    local max = {}

    for key, value in pairs(tierCeilings) do max[key] = value * settings.cards.maxCeilingMultiplier end

    local clean = rules.clampLimits(requested, max)

    if not clean then return fail('bad_amount') end

    MySQL.update.await('UPDATE `bank_cards` SET `ceilings` = ? WHERE `id` = ?', { json.encode(clean), id })
    access.audit(actor, 'ceiling_set', card.holder, { card = card.last4, ceilings = clean })

    return { ok = true }
end)

---Freezes ('fraud' / 'admin') or unfreezes an account. A debt freeze can be lifted here after negotiating.
staff('staffFreeze', function(src, player, actor, accountId, reason)
    accountId = access.int(accountId)

    local account = accountId and exports.city_economy:BankGetAccount(accountId)

    if not account or account.type == 'system' then return fail('no_account') end
    if reason ~= false and reason ~= 'fraud' and reason ~= 'admin' then return fail('bad_request') end
    if accounts.perms(player, account) then return ownBusiness(src, 'freeze') end

    -- Bankers lift debt freezes after negotiating; fraud and staff freezes are for admins to lift
    if reason == false and account.frozen and account.frozen ~= 'debt' and not access.isAdmin(src) then
        return fail('no_permission')
    end

    exports.city_economy:BankSetFrozen(account.id, reason)
    access.audit(actor, reason and 'freeze' or 'unfreeze', account.owner or '-', { account = account.display, reason = reason })

    return { ok = true }
end)

-- Admins only: who the bankers are
access.panel('staffBankers', function(src)
    if not access.isAdmin(src) then return fail('no_permission') end

    return { ok = true, bankers = MySQL.query.await('SELECT `citizenid`, `name`, `added_by`, `created_at` FROM `bank_bankers` ORDER BY `created_at`') or {} }
end)

access.panel('staffSetBanker', function(src, player, _, targetId, add)
    if not access.isAdmin(src) then
        exports.city_economy:Flag(src, 'bank_admin_denied', 3, { action = 'setBanker' })
        return fail('no_permission')
    end

    local actor = access.name(player)

    if add == true then
        targetId = access.int(targetId)

        local target = targetId and exports.qbx_core:GetPlayer(targetId)

        if not target then return fail('no_player') end

        MySQL.insert.await(
            'INSERT IGNORE INTO `bank_bankers` (`citizenid`, `name`, `added_by`, `created_at`) VALUES (?, ?, ?, ?)',
            { target.PlayerData.citizenid, access.name(target), actor, os.time() }
        )
        access.audit(actor, 'banker_add', target.PlayerData.citizenid, {})
    else
        if type(targetId) ~= 'string' then return fail('bad_request') end

        MySQL.update.await('DELETE FROM `bank_bankers` WHERE `citizenid` = ?', { targetId })
        access.audit(actor, 'banker_remove', targetId, {})
    end

    access.loadBankers()

    return { ok = true }
end)
