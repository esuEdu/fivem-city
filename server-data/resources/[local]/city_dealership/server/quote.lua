-- Financing math, kept apart so the plain-Lua tests in tests/city_dealership can run it.
local quote = {}

---@param list integer[]
---@param value any
---@return boolean
local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end

    return false
end

---A financing plan, or nil when the down payment or the number of installments isn't allowed.
---Rounding favours the dealership: the down payment and interest round up, the last installment takes the rest.
---@param price integer
---@param downPct integer
---@param count integer
---@param finance { minDownPct: integer, installments: integer[], interestPct: number }
---@return { down: integer, financed: integer, debt: integer, installment: integer, last: integer, count: integer }?
function quote.plan(price, downPct, count, finance)
    if math.tointeger(price) == nil or price <= 0 then return end
    if math.tointeger(downPct) == nil or downPct < finance.minDownPct or downPct > 90 then return end
    if not contains(finance.installments, count) then return end

    local down = math.ceil(price * downPct / 100)
    local financed = price - down
    local debt = financed + math.ceil(financed * finance.interestPct / 100)
    local installment = math.floor(debt / count)

    return {
        down = down,
        financed = financed,
        debt = debt,
        installment = installment,
        last = debt - installment * (count - 1),
        count = count,
    }
end

---What is still to be billed after `issued` installments
---@param debt integer
---@param installment integer
---@param count integer
---@param issued integer
---@return integer
function quote.unissued(debt, installment, count, issued)
    if issued >= count then return 0 end

    return debt - installment * issued
end

return quote
