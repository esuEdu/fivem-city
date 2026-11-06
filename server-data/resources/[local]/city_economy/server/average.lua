-- Time-weighted average balance (savings yield, BANCO_DESIGN.md 3.1). Pure, so tests/city_economy can check it.
local average = {}

---@param startBalance integer balance at the start of the window
---@param changes { time: integer, balance: integer }[] balances after each movement inside the window, oldest first
---@param from integer window start (unix seconds)
---@param to integer window end
---@return integer average rounded down (in favour of the bank)
function average.balance(startBalance, changes, from, to)
    if to <= from then return 0 end

    local total, current, last = 0, startBalance, from

    for i = 1, #changes do
        local change = changes[i]
        local at = math.max(from, math.min(to, change.time))

        total = total + current * (at - last)
        current = change.balance
        last = at
    end

    total = total + current * (to - last)

    return math.floor(total / (to - from))
end

return average
