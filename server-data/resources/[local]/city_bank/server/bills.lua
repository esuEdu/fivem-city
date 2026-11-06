-- Bills owed by a character: fines, services, card invoices, loan installments (BANCO_DESIGN.md 7, 13.4).
-- Players only see and pay their own; they never bill anyone from here.
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local bills = {}

local KINDS = { fine = true, service = true, card = true, loan = true, admin = true }

---Turns a payee list into ledger accounts. A fine's police share stops once the police got their cap this month.
---@param payees table[]
---@return { account: integer, pct: number }[]
local function payeeAccounts(payees)
    local out = {}

    for i = 1, #payees do
        local payee = payees[i]
        local account = payee.system and money.system(payee.system)
            or payee.job and exports.city_economy:BankCreateAccount('job', payee.job, payee.job)

        if type(account) == 'table' then
            local received = exports.city_economy:BankReceived(account.id, 'bank-bill', settings.fines.policeWindow)

            if payee.job == settings.fines.policeJob and received >= settings.fines.policeCap then
                account = money.system('GOV_TREASURY')
            else
                account = account.id
            end
        end

        if account then out[#out + 1] = { account = account, pct = payee.pct } end
    end

    return out
end

---@param data { citizenid: string, kind: string, label: string, issuer: string, amount: integer, minimum?: integer, due?: integer, payees: table[], ref?: string }
---@return integer? id
function bills.create(data)
    if not KINDS[data.kind] or math.type(data.amount) ~= 'integer' or data.amount <= 0 then return end

    local id = MySQL.insert.await(
        'INSERT INTO `bank_bills` (`citizenid`, `kind`, `label`, `issuer`, `amount`, `minimum`, `payees`, `due_at`, `created_at`, `ref`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            data.citizenid, data.kind, data.label:sub(1, 80), data.issuer:sub(1, 80), data.amount, data.minimum or 0,
            json.encode(data.payees), data.due or (os.time() + settings.bills.dueAfter), os.time(), data.ref or '',
        }
    )

    money.notify(data.citizenid, locale('notify_bill', data.label, data.amount))

    return id
end

---What paying a bill in full costs right now (remaining + late fee)
---@param bill table
---@return integer remaining
---@return integer fee
function bills.due(bill)
    local remaining = bill.amount - bill.paid
    local days = bill.status == 'overdue' and math.max(0, math.floor((os.time() - bill.due_at) / 86400)) or 0

    return remaining, rules.lateFee(remaining, days, settings.bills)
end

---Pays part or all of a bill from an account. The late fee is charged on what is paid.
---@param bill table
---@param fromId integer
---@param amount integer the part of the bill to settle (without fee)
---@param reason string
---@return boolean ok
---@return string? error
function bills.pay(bill, fromId, amount, reason)
    local remaining = bill.amount - bill.paid

    amount = math.min(amount, remaining)

    if amount <= 0 then return false, 'bad_amount' end

    local _, fullFee = bills.due(bill)
    local fee = remaining > 0 and rules.debit(fullFee * amount / remaining) or 0
    local total = amount + fee
    local targets = payeeAccounts(json.decode(bill.payees) or {})

    if #targets == 0 then targets = { { account = money.system('GOV_TREASURY'), pct = 100 } } end

    local pcts = {}
    for i = 1, #targets do pcts[i] = targets[i].pct end

    local parts = rules.split(total, pcts)
    local entries = { { account = fromId, delta = -total } }

    for i = 1, #targets do
        if parts[i] > 0 then entries[#entries + 1] = { account = targets[i].account, delta = parts[i] } end
    end

    local ok, err = money.post(entries, reason, bill.citizenid, { bill = bill.id, fee = fee })

    if not ok then return false, err end

    local paidOff = bill.paid + amount >= bill.amount

    MySQL.update.await(
        'UPDATE `bank_bills` SET `paid` = `paid` + ?, `status` = IF(?, \'paid\', `status`) WHERE `id` = ?',
        { amount, paidOff, bill.id }
    )

    bill.paid = bill.paid + amount

    if paidOff then TriggerEvent('city_bank:server:billPaid', bill) end

    return true
end

---Bills of a character, newest first
---@param citizenid string
---@return table[]
function bills.list(citizenid)
    return MySQL.query.await(
        [[SELECT * FROM `bank_bills` WHERE `citizenid` = ? AND (`status` IN ('pending', 'overdue') OR `created_at` >= ?) ORDER BY FIELD(`status`, 'overdue', 'pending', 'paid', 'cancelled'), `id` DESC LIMIT 50]],
        { citizenid, os.time() - 14 * 86400 }
    ) or {}
end

---Due dates passing: card bills with the minimum paid roll over, everything else unpaid becomes overdue
---@param carry fun(citizenid: string, remaining: integer)
function bills.processDue(carry)
    local rows = MySQL.query.await(
        [[SELECT * FROM `bank_bills` WHERE `status` = 'pending' AND `due_at` <= ? LIMIT 200]],
        { os.time() }
    ) or {}

    for i = 1, #rows do
        local bill = rows[i]

        if bill.kind == 'card' and bill.minimum > 0 and bill.paid >= bill.minimum then
            MySQL.update.await([[UPDATE `bank_bills` SET `status` = 'paid' WHERE `id` = ?]], { bill.id })
            carry(bill.citizenid, bill.amount - bill.paid)
            profile.addScore(bill.citizenid, 'minimumOnly')
        else
            MySQL.update.await([[UPDATE `bank_bills` SET `status` = 'overdue' WHERE `id` = ?]], { bill.id })
            profile.addScore(bill.citizenid, 'overdue')
            money.notify(bill.citizenid, locale('notify_bill_overdue', bill.label), 'error')
        end
    end
end

---Once a day: score loss per overdue day, and the debt freeze after the configured days
function bills.daily()
    local rows = MySQL.query.await(
        [[SELECT `citizenid`, MIN(`due_at`) AS `due` FROM `bank_bills` WHERE `status` = 'overdue' GROUP BY `citizenid`]]
    ) or {}

    for i = 1, #rows do
        local citizenid = rows[i].citizenid
        local days = math.floor((os.time() - rows[i].due) / 86400)

        profile.addScore(citizenid, 'overduePerDay')

        if days >= settings.bills.freeze then
            local personal = money.owned(citizenid, 'personal')

            if personal and not personal.frozen then
                exports.city_economy:BankSetFrozen(personal.id, 'debt')
                profile.addScore(citizenid, 'frozenForDebt')
                money.notify(citizenid, locale('notify_frozen_debt'), 'error')
            end
        end
    end
end

---Money coming into a debtor's personal account: part of it pays their overdue bills (oldest first)
---@param accountId integer
---@param citizenid string
---@param amount integer
function bills.retain(accountId, citizenid, amount)
    local overdue = MySQL.query.await(
        [[SELECT * FROM `bank_bills` WHERE `citizenid` = ? AND `status` = 'overdue' ORDER BY `due_at`]],
        { citizenid }
    ) or {}

    local budget = rules.pctCredit(amount, settings.bills.retentionPct)

    for i = 1, #overdue do
        if budget <= 0 then break end

        local remaining, fee = bills.due(overdue[i])
        local part = math.min(remaining, math.floor(budget * remaining / (remaining + fee)))

        if part > 0 and bills.pay(overdue[i], accountId, part, 'bank-retention') then
            budget = budget - part - rules.debit(fee * part / remaining)
        end
    end
end

return bills
