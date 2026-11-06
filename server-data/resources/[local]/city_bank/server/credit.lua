-- Credit function of the cards: purchases add up during a 7-day cycle and become a 'card' bill (BANCO_DESIGN.md 4, 13.3)
local cards = require 'server.cards'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local credit = {}

---What is still owed on card bills that aren't settled yet
---@param citizenid string
---@return integer
local function openBills(citizenid)
    local value = MySQL.scalar.await(
        [[SELECT CAST(COALESCE(SUM(`amount` - `paid`), 0) AS SIGNED) FROM `bank_bills` WHERE `citizenid` = ? AND `kind` = 'card' AND `status` IN ('pending', 'overdue')]],
        { citizenid }
    )

    return math.tointeger(value) or 0
end

---Everything owed on credit: this cycle's purchases plus open card bills
---@param citizenid string
---@return integer used
---@return integer limit
function credit.usage(citizenid)
    local row = profile.get(citizenid)
    local tier = profile.tier(citizenid)

    return row.credit_used + openBills(citizenid), tier.creditLimit
end

---Why a credit purchase can't go through, or nil when it can
---@param card table
---@param amount integer
---@param limits table
---@return string?
function credit.check(card, amount, limits)
    if not profile.restrictions(card.holder).creditCard then return 'credit_blocked' end

    local used, limit = credit.usage(card.holder)

    if used + amount > limit then return 'credit_limit' end
    if cards.spentToday(card.card_id, { 'credit' }) + amount > (limits.creditDay or 0) then return 'card_limit' end
end

---@param citizenid string
---@param amount integer
function credit.use(citizenid, amount)
    profile.get(citizenid)

    MySQL.update.await(
        'UPDATE `bank_profiles` SET `credit_used` = `credit_used` + ?, `cycle_start` = IF(`cycle_start` = 0, ?, `cycle_start`) WHERE `citizenid` = ?',
        { amount, os.time(), citizenid }
    )
end

---Closes every cycle that reached 7 days: the purchases (plus the tier fee) become a card bill
---@param createBill fun(data: table): integer?
function credit.closeCycles(createBill)
    local now = os.time()
    local rows = MySQL.query.await(
        'SELECT `citizenid`, `credit_used` FROM `bank_profiles` WHERE `cycle_start` > 0 AND `cycle_start` <= ? LIMIT 200',
        { now - settings.invoice.cycle }
    ) or {}

    for i = 1, #rows do
        local row = rows[i]
        local tier = profile.tier(row.citizenid)
        local total = row.credit_used + (row.credit_used > 0 and tier.fee or 0)

        if total > 0 then
            createBill({
                citizenid = row.citizenid,
                kind = 'card',
                label = ('%s card invoice'):format(tier.label),
                issuer = 'Bank',
                amount = total,
                minimum = rules.pctDebit(total, settings.invoice.minimumPct),
                due = now + settings.invoice.dueAfter,
                payees = { { system = 'BANK_RESERVE', pct = 100 } },
            })
        end

        MySQL.update.await(
            'UPDATE `bank_profiles` SET `credit_used` = 0, `cycle_start` = 0 WHERE `citizenid` = ?',
            { row.citizenid }
        )
    end
end

---What is left of a card bill after only the minimum was paid moves to the next cycle, with revolving interest
---@param citizenid string
---@param remaining integer
function credit.carry(citizenid, remaining)
    if remaining <= 0 then return end

    credit.use(citizenid, remaining + rules.pctDebit(remaining, settings.invoice.revolvingPct))
end

return credit
