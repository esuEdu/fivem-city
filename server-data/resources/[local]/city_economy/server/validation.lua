-- Plain checks with no natives, so tests/city_economy can run them outside the game
local validation = {}

---A whole, positive amount no bigger than max. Strings are refused, not converted: a real client always sends numbers.
---@param value unknown
---@param max integer
---@return integer?
function validation.amount(value, max)
    if type(value) ~= 'number' then return nil end

    local whole = math.tointeger(value)

    if not whole or whole <= 0 or whole > max then return nil end

    return whole
end

---Ledger entries must move whole amounts and add up to zero (double entry: money never appears or vanishes).
---@param entries { account: integer, delta: integer }[]
---@return boolean ok
---@return string? reason
function validation.entries(entries)
    if type(entries) ~= 'table' or #entries < 2 then return false, 'need two sides' end

    local sum, seen = 0, {}

    for i = 1, #entries do
        local entry = entries[i]

        if type(entry) ~= 'table' or type(entry.account) ~= 'number' or not math.tointeger(entry.account) then
            return false, 'bad account'
        end

        if type(entry.delta) ~= 'number' or not math.tointeger(entry.delta) or entry.delta == 0 then
            return false, 'bad delta'
        end

        if seen[entry.account] then return false, 'account twice' end

        seen[entry.account] = true
        sum = sum + entry.delta
    end

    if sum ~= 0 then return false, 'unbalanced' end

    return true
end

---Whether one side of a posting may end at this balance. System accounts (mint, sink) may go negative.
---@param balance integer
---@param delta integer
---@param isSystem boolean
---@param maxBalance integer
---@return boolean ok
---@return string? reason
function validation.fits(balance, delta, isSystem, maxBalance)
    if isSystem then return true end

    local after = balance + delta

    if after < 0 then return false, 'insufficient funds' end
    if after > maxBalance then return false, 'balance limit' end

    return true
end

---Formats a stored account number (8 digits) the way players see it: LS 5801 8396
---@param number string
---@return string
function validation.formatAccount(number)
    return ('LS %s %s'):format(number:sub(1, 4), number:sub(5, 8))
end

return validation
