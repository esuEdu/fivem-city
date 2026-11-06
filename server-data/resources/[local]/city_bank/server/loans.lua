-- Loans (BANCO_DESIGN.md 8, 13.1): automatic up to the tier's amount, bigger ones wait for a banker.
-- Weekly installments are charged from the personal account; a missed one becomes an overdue 'loan' bill.
local access = require 'server.access'
local bills = require 'server.bills'
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local loans = {}

local WEEK = settings.loans.every
local MAX_MULTIPLIER = 4 -- the biggest request a banker can approve: 4x the automatic amount

local function fail(code) return { ok = false, error = code } end

---@param citizenid string
---@return table?
local function openLoan(citizenid)
    return MySQL.single.await(
        [[SELECT * FROM `bank_loans` WHERE `citizenid` = ? AND `status` IN ('requested', 'active') LIMIT 1]],
        { citizenid }
    )
end

---Pays the money out and starts the installments
---@param loan table
---@return boolean
function loans.disburse(loan)
    local ok = money.move(money.system('BANK_RESERVE'), loan.account_id, loan.amount, 'bank-loan', loan.citizenid, { loan = loan.id })

    if not ok then return false end

    MySQL.update.await(
        [[UPDATE `bank_loans` SET `status` = 'active', `next_due` = ? WHERE `id` = ?]],
        { os.time() + WEEK, loan.id }
    )

    return true
end

---@param loan table
---@return integer
local function installmentAmount(loan)
    if loan.paid_count + 1 >= loan.installments then return loan.total - loan.paid_total end
    return loan.installment
end

---Takes one installment. On failure the installment becomes a loan bill (overdue rules apply).
---@param loan table
---@param manual boolean paid by the player from the panel
---@return boolean paid
function loans.charge(loan, manual)
    local amount = installmentAmount(loan)
    local ok = money.move(loan.account_id, money.system('BANK_RESERVE'), amount, 'bank-loan-payment', loan.citizenid, { loan = loan.id })

    if not ok then
        if manual then return false end

        bills.create({
            citizenid = loan.citizenid, kind = 'loan', label = ('Loan #%d installment'):format(loan.id), issuer = 'Bank',
            amount = amount, due = os.time(), payees = { { system = 'BANK_RESERVE', pct = 100 } }, ref = tostring(loan.id),
        })
    else
        profile.addScore(loan.citizenid, 'installmentPaid')
    end

    local count = loan.paid_count + 1
    local done = count >= loan.installments

    MySQL.update.await(
        'UPDATE `bank_loans` SET `paid_count` = ?, `paid_total` = `paid_total` + ?, `status` = ?, `next_due` = ? WHERE `id` = ?',
        { count, amount, done and 'paid' or 'active', done and 0 or loan.next_due + WEEK, loan.id }
    )

    if done and ok then profile.addScore(loan.citizenid, 'loanRepaid') end

    return ok
end

function loans.runDue()
    local rows = MySQL.query.await(
        [[SELECT * FROM `bank_loans` WHERE `status` = 'active' AND `next_due` <= ? LIMIT 100]],
        { os.time() }
    ) or {}

    for i = 1, #rows do loans.charge(rows[i], false) end
end

access.panel('loans', function(_, _, citizenid)
    local tier, score = profile.tier(citizenid)
    local rows = MySQL.query.await(
        'SELECT `id`, `amount`, `rate`, `total`, `installments`, `installment`, `paid_count`, `paid_total`, `status`, `reason`, `next_due`, `decision`, `created_at` FROM `bank_loans` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 10',
        { citizenid }
    ) or {}

    for i = 1, #rows do rows[i].rate = tonumber(rows[i].rate) end

    return {
        ok = true, score = score, tier = tier.label, auto = tier.loanAuto, max = tier.loanAuto * MAX_MULTIPLIER,
        rate = tier.loanRate, weeks = tier.loanWeeks, min = settings.loans.minAmount,
        canRequest = profile.restrictions(citizenid).newCredit and openLoan(citizenid) == nil, loans = rows,
    }
end)

access.panel('requestLoan', function(_, player, citizenid, amount, weeks, reason)
    local tier = profile.tier(citizenid)

    amount = access.int(amount)
    weeks = access.int(weeks)

    if not amount or amount < settings.loans.minAmount or amount > tier.loanAuto * MAX_MULTIPLIER then return fail('bad_amount') end
    if not weeks or weeks < 1 or weeks > tier.loanWeeks then return fail('bad_request') end
    if not profile.restrictions(citizenid).newCredit then return fail('credit_blocked') end
    if openLoan(citizenid) then return fail('loan_open') end

    local personal = money.owned(citizenid, 'personal')
    local total, installment = rules.loanPlan(amount, tier.loanRate, weeks)
    local auto = amount <= tier.loanAuto

    local id = MySQL.insert.await(
        'INSERT INTO `bank_loans` (`citizenid`, `name`, `account_id`, `amount`, `rate`, `total`, `installments`, `installment`, `status`, `reason`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, access.name(player), personal.id, amount, tier.loanRate, total, weeks, installment, 'requested',
            type(reason) == 'string' and reason:sub(1, 120) or '', os.time() }
    )

    if not auto then return { ok = true, pending = true } end

    local loan = MySQL.single.await('SELECT * FROM `bank_loans` WHERE `id` = ?', { id })

    MySQL.update.await([[UPDATE `bank_loans` SET `decided_by` = 'automatic' WHERE `id` = ?]], { id })

    if not loans.disburse(loan) then
        MySQL.update.await([[UPDATE `bank_loans` SET `status` = 'denied', `decision` = 'bank unavailable' WHERE `id` = ?]], { id })
        return fail('failed')
    end

    return { ok = true, pending = false }
end)

access.panel('payInstallment', function(_, _, citizenid, id)
    id = access.int(id)

    local loan = id and MySQL.single.await(
        [[SELECT * FROM `bank_loans` WHERE `id` = ? AND `citizenid` = ? AND `status` = 'active']],
        { id, citizenid }
    )

    if not loan then return fail('no_loan') end

    return loans.charge(loan, true) and { ok = true } or fail('insufficient')
end)

return loans
