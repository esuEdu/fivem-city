-- Plain rules with no game calls, so tests can run them: what a local offers, whether a recipe can be made, chances.
-- `rng(a, b)` is math.random in the game and a fixed sequence in tests.
local rules = {}

---Whether a roll out of 100 lands inside `percent`
---@param percent number
---@param rng fun(a: integer, b: integer): integer
---@return boolean
function rules.chance(percent, rng)
    return percent > 0 and rng(1, 100) <= percent
end

---The chance (percent) of a police call: the drug's base for this act, plus a point per `perPoint` dollars, capped
---@param risk { perPoint?: number, max?: number, [string]: number }
---@param act string 'pick' | 'lab' | 'sale' | 'refuse'
---@param total? number dollars the act made
---@return integer
function rules.risk(risk, act, total)
    local chance = risk[act] or 0

    if total and total > 0 and (risk.perPoint or 0) > 0 then
        chance = chance + math.floor(total / risk.perPoint)
    end

    return math.max(0, math.min(chance, risk.max or 100))
end

---What a local offers for the drugs the player carries: one of them, some units, a price per unit
---@param counts table<string, integer> item -> count the player has
---@param prices table<string, { drug?: string, min: integer, max: integer, maxUnits: integer }>
---@param rng fun(a: integer, b: integer): integer
---@return { item: string, drug?: string, amount: integer, total: integer }?
function rules.offer(counts, prices, rng)
    local carried = {}

    for item, price in pairs(prices) do
        if (counts[item] or 0) > 0 then carried[#carried + 1] = { item = item, price = price } end
    end

    if #carried == 0 then return end

    -- pairs order isn't stable, so pick from a sorted list
    table.sort(carried, function(a, b) return a.item < b.item end)

    local pick = carried[rng(1, #carried)]
    local amount = rng(1, math.min(counts[pick.item], pick.price.maxUnits))

    return { item = pick.item, drug = pick.price.drug, amount = amount, total = rng(pick.price.min, pick.price.max) * amount }
end

---Whether the counts cover every input of a recipe
---@param counts table<string, integer>
---@param inputs table<string, integer>
---@return boolean
function rules.canMake(counts, inputs)
    for item, needed in pairs(inputs) do
        if (counts[item] or 0) < needed then return false end
    end

    return true
end

---A deal order: which item, how many and the payout
---@param orders { drug?: string, item: string, min: integer, max: integer, pricePerUnit: integer }[]
---@param rng fun(a: integer, b: integer): integer
---@return { drug?: string, item: string, amount: integer, payout: integer }?
function rules.order(orders, rng)
    if #orders == 0 then return end

    local order = orders[rng(1, #orders)]
    local amount = rng(order.min, order.max)

    return { drug = order.drug, item = order.item, amount = amount, payout = amount * order.pricePerUnit }
end

return rules
