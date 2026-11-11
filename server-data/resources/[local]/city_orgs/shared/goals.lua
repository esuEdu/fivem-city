-- Farm goal arithmetic, pure so the unit tests in tests/city_orgs/ run it outside the game.
local goals = {}

---@class FarmGoal
---@field mode 'each' | 'total'
---@field amount integer? mode 'total': items delivered across the listed items
---@field items table mode 'each': item -> required; mode 'total': array of item names that count

---@class FarmProgress
---@field deposited integer put in the vault (goal items only)
---@field withdrawn integer taken out of the vault
---@field net integer deposited - withdrawn
---@field percent number 0..1 toward the goal
---@field complete boolean
---@field items { name: string, required: integer?, net: integer }[]

local MAX_AMOUNT = 1000000

---@param value unknown
---@return integer?
local function toAmount(value)
    value = math.tointeger(tonumber(value))

    return value and value > 0 and value <= MAX_AMOUNT and value or nil
end

---Checks a goal a leader typed; only items from `allowed` count.
---@param mode unknown
---@param items unknown mode 'each': { [name] = required }; mode 'total': ignored
---@param amount unknown mode 'total' only
---@param allowed string[]
---@return FarmGoal?
---@return string? error
function goals.validate(mode, items, amount, allowed)
    local names = {}

    for i = 1, #allowed do
        names[allowed[i]] = true
    end

    if mode == 'total' then
        local total = toAmount(amount)
        if not total then return nil, 'invalid_amount' end

        local list = {}

        for i = 1, #allowed do
            list[i] = allowed[i]
        end

        return { mode = 'total', amount = total, items = list }
    end

    if mode ~= 'each' or type(items) ~= 'table' then return nil, 'invalid_goal' end

    local each = {}
    local any = false

    for name, required in pairs(items) do
        local value = toAmount(required)

        if names[name] and value then
            each[name] = value
            any = true
        elseif names[name] and (required == 0 or required == '0' or required == '') then
            -- an item left out of the goal
        elseif not names[name] then
            return nil, 'invalid_item'
        else
            return nil, 'invalid_amount'
        end
    end

    if not any then return nil, 'empty_goal' end

    return { mode = 'each', items = each }
end

---@param goal FarmGoal
---@return string[] the item names the goal counts
function goals.itemNames(goal)
    if goal.mode == 'total' then return goal.items end

    local names = {}

    for name in pairs(goal.items) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

---What one member did toward a goal.
---@param goal FarmGoal
---@param totals table<string, { deposited: integer, withdrawn: integer }> that member's counters per item
---@return FarmProgress
function goals.progress(goal, totals)
    local result = { deposited = 0, withdrawn = 0, net = 0, items = {} }
    local names = goals.itemNames(goal)
    local percent, complete = 1, true

    for i = 1, #names do
        local name = names[i]
        local counted = totals[name]
        local deposited = counted and counted.deposited or 0
        local withdrawn = counted and counted.withdrawn or 0
        local net = deposited - withdrawn

        result.deposited = result.deposited + deposited
        result.withdrawn = result.withdrawn + withdrawn
        result.net = result.net + net

        local required = goal.mode == 'each' and goal.items[name] or nil
        result.items[i] = { name = name, required = required, net = net }

        if required then
            percent = math.min(percent, math.max(net, 0) / required)
            complete = complete and net >= required
        end
    end

    if goal.mode == 'total' then
        percent = math.min(math.max(result.net, 0) / goal.amount, 1)
        complete = result.net >= goal.amount
    end

    result.percent = percent
    result.complete = complete

    return result
end

return goals
