-- The Goals tab: the daily and weekly farm goals the leader sets, and every member's progress with what they put
-- in and took out shown side by side (the contribution ranking).
local orgs = require 'server.orgs'
local farm = require 'server.farm'
local rules = require 'shared.goals'
local core = require 'server.app.main'

core.register('goals', function(_, _, faction)
    local goals = farm.goals(faction.gang)
    local result = {}

    for _, period in ipairs({ 'daily', 'weekly' }) do
        result[period] = {
            goal = goals[period],
            rows = farm.progressRows(faction.gang, faction, period, goals[period]),
        }
    end

    return true, result
end)

---@param value unknown
---@return 'daily' | 'weekly' | nil
local function toPeriod(value)
    return (value == 'daily' or value == 'weekly') and value or nil
end

core.register('setGoal', function(_, player, faction, data)
    local period = toPeriod(data.period)
    if not period then return false, 'invalid' end

    local goal, err = rules.validate(data.mode, data.items, data.amount, faction.farmItems)
    if not goal then return false, err end

    farm.setGoal(faction.gang, period, goal)

    local parts = {}

    if goal.mode == 'total' then
        parts[1] = ('any x%d'):format(goal.amount)
    else
        for _, name in ipairs(rules.itemNames(goal)) do
            parts[#parts + 1] = ('%s x%d'):format(name, goal.items[name])
        end
    end

    orgs.log(faction.gang, player.PlayerData.citizenid, 'goal_set', ('%s: %s'):format(period, table.concat(parts, ', ')))
    orgs.refresh(faction.gang, 'data')

    return true
end, { boss = true })

core.register('clearGoal', function(_, player, faction, data)
    local period = toPeriod(data.period)
    if not period then return false, 'invalid' end

    farm.clearGoal(faction.gang, period)
    orgs.log(faction.gang, player.PlayerData.citizenid, 'goal_clear', period)
    orgs.refresh(faction.gang, 'data')

    return true
end, { boss = true })
