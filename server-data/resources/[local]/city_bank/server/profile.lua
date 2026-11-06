-- Credit score, tier and debt restrictions of a character (BANCO_DESIGN.md 7, 13.1, 13.2)
local rules = require 'server.rules'
local settings = require 'server.config'

local profile = {}

local WEEK = 7 * 86400

---@param citizenid string
---@return { score: integer, week_start: integer, week_gain: integer, credit_used: integer, cycle_start: integer }
function profile.get(citizenid)
    local row = MySQL.single.await('SELECT * FROM `bank_profiles` WHERE `citizenid` = ?', { citizenid })

    if row then return row end

    MySQL.insert.await(
        'INSERT IGNORE INTO `bank_profiles` (`citizenid`, `score`, `week_start`) VALUES (?, ?, ?)',
        { citizenid, settings.score.start, os.time() }
    )

    return MySQL.single.await('SELECT * FROM `bank_profiles` WHERE `citizenid` = ?', { citizenid })
end

---@param citizenid string
---@return table tier
---@return integer score
function profile.tier(citizenid)
    local row = profile.get(citizenid)

    return rules.tierFor(settings.tiers, row.score), row.score
end

---Adds score points (gains capped per week). key is a settings.score entry, e.g. 'invoicePaid'.
---@param citizenid string
---@param key string
---@param times? integer
function profile.addScore(citizenid, key, times)
    local delta = (settings.score[key] or 0) * (times or 1)

    if delta == 0 then return end

    local row = profile.get(citizenid)
    local weekStart, weekGain = row.week_start, row.week_gain

    if os.time() - weekStart >= WEEK then weekStart, weekGain = os.time(), 0 end

    local score, gain = rules.applyScore(row.score, delta, weekGain, settings.score)

    MySQL.update.await(
        'UPDATE `bank_profiles` SET `score` = ?, `week_start` = ?, `week_gain` = ? WHERE `citizenid` = ?',
        { score, weekStart, gain, citizenid }
    )
end

---Days the oldest unpaid overdue bill is late (0 when there is none overdue)
---@param citizenid string
---@return integer days
---@return boolean hasOverdue
function profile.overdue(citizenid)
    local due = MySQL.scalar.await(
        [[SELECT MIN(`due_at`) FROM `bank_bills` WHERE `citizenid` = ? AND `status` = 'overdue']],
        { citizenid }
    )

    due = math.tointeger(due)

    if not due then return 0, false end

    return math.max(0, math.floor((os.time() - due) / 86400)), true
end

---What the debt rules allow right now
---@param citizenid string
---@return { newCredit: boolean, creditCard: boolean, pixDay: integer? }
function profile.restrictions(citizenid)
    local days, overdue = profile.overdue(citizenid)
    local bills = settings.bills

    return {
        newCredit = not overdue,
        creditCard = not overdue or days < bills.creditBlocked,
        pixDay = (overdue and days >= bills.pixLimited) and bills.pixLimitedDay or nil,
        overdueDays = overdue and days or nil,
    }
end

---The ceilings a card gets by default: its holder's current tier
---@param tier table
---@return table<string, integer>
function profile.tierCeilings(tier)
    return {
        debitDay = tier.debitDay,
        creditDay = tier.creditLimit,
        atmDay = tier.atmDay,
        contactlessTx = tier.contactlessTx,
        contactlessDay = tier.contactlessDay,
    }
end

return profile
