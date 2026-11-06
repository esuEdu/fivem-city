-- Plain bank arithmetic with no natives or database, so tests/city_bank can check it.
local rules = {}

---@param tiers table[] ordered low to high
---@param score integer
---@return table tier
---@return integer index
function rules.tierFor(tiers, score)
    local found, index = tiers[1], 1

    for i = 1, #tiers do
        if score >= tiers[i].minScore then found, index = tiers[i], i end
    end

    return found, index
end

---Money the player receives is rounded down, money they pay is rounded up (PROMPT_ECONOMIA_FIVEM.md rule 21)
function rules.credit(value) return math.floor(value) end
function rules.debit(value) return math.ceil(value) end

---@param amount integer
---@param pct number
---@return integer
function rules.pctDebit(amount, pct)
    return rules.debit(amount * pct / 100)
end

---@param amount integer
---@param pct number
---@return integer
function rules.pctCredit(amount, pct)
    return rules.credit(amount * pct / 100)
end

---Late fee: flat % plus % per day, capped
---@param amount integer
---@param daysLate integer
---@param cfg { lateFlatPct: number, latePerDayPct: number, lateMaxPct: number }
---@return integer
function rules.lateFee(amount, daysLate, cfg)
    if daysLate <= 0 then return 0 end

    local pct = math.min(cfg.lateFlatPct + cfg.latePerDayPct * daysLate, cfg.lateMaxPct)

    return rules.pctDebit(amount, pct)
end

---Splits a total by percentages; the parts always add up to the total (the remainder goes to the first part)
---@param total integer
---@param pcts number[]
---@return integer[]
function rules.split(total, pcts)
    local parts, sum = {}, 0

    for i = 1, #pcts do
        parts[i] = math.floor(total * pcts[i] / 100)
        sum = sum + parts[i]
    end

    parts[1] = parts[1] + (total - sum)

    return parts
end

---Loan with fixed weekly installments; the last one absorbs the rounding
---@param amount integer
---@param ratePct number total interest
---@param count integer
---@return integer total
---@return integer installment
---@return integer last
function rules.loanPlan(amount, ratePct, count)
    local total = amount + rules.pctDebit(amount, ratePct)
    local installment = rules.debit(total / count)
    local last = total - installment * (count - 1)

    return total, installment, last
end

---Keeps each requested limit between 0 and its ceiling
---@param requested table<string, unknown>
---@param ceilings table<string, integer>
---@return table<string, integer>? limits nil when something isn't a whole number
function rules.clampLimits(requested, ceilings)
    local limits = {}

    for key, ceiling in pairs(ceilings) do
        local value = requested[key]

        if type(value) ~= 'number' or not math.tointeger(value) then return nil end

        limits[key] = math.max(0, math.min(math.tointeger(value), ceiling))
    end

    return limits
end

---Whether a given hour (0-23) falls in a window that may wrap past midnight (22 -> 6)
function rules.inWindow(hour, from, to)
    if from <= to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

---'John Doe' -> 'J*** D**' so a transfer shows who receives it without exposing the full name
function rules.maskName(first, last)
    local function mask(word)
        word = tostring(word or '')
        if #word <= 1 then return word end
        return word:sub(1, 1) .. ('*'):rep(math.min(#word - 1, 6))
    end

    return ('%s %s'):format(mask(first), mask(last))
end

---Four-digit PIN as a string, like the client sends it
function rules.validPin(pin)
    return type(pin) == 'string' and pin:match('^%d%d%d%d$') ~= nil
end

---Score change with a weekly cap on gains (losses are never capped)
---@param score integer
---@param delta integer
---@param weekGain integer gains already counted this week
---@param cfg { min: integer, max: integer, weeklyGainCap: integer }
---@return integer score
---@return integer weekGain
function rules.applyScore(score, delta, weekGain, cfg)
    if delta > 0 then
        delta = math.max(0, math.min(delta, cfg.weeklyGainCap - weekGain))
        weekGain = weekGain + delta
    end

    return math.max(cfg.min, math.min(cfg.max, score + delta)), weekGain
end

return rules
