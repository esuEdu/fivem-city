dofile('harness.lua')

local goals = require('shared.goals')

local allowed = { 'farm_test1', 'farm_test2' }

-- validate: per-item goals keep only positive amounts for allowed items
local goal, err = goals.validate('each', { farm_test1 = 100, farm_test2 = 0 }, nil, allowed)
check(goal, ('each goal refused: %s'):format(tostring(err)))
check(goal.mode == 'each', 'mode kept')
check(goal.items.farm_test1 == 100, 'amount kept')
check(goal.items.farm_test2 == nil, 'zero means left out')

-- validate: a goal with no amounts is refused
goal, err = goals.validate('each', { farm_test1 = 0 }, nil, allowed)
check(goal == nil and err == 'empty_goal', 'empty goal refused')

-- validate: unknown items and bad amounts are refused
check(select(2, goals.validate('each', { stone = 5 }, nil, allowed)) == 'invalid_item', 'unknown item refused')
check(select(2, goals.validate('each', { farm_test1 = -5 }, nil, allowed)) == 'invalid_amount', 'negative refused')
check(select(2, goals.validate('each', { farm_test1 = 10.5 }, nil, allowed)) == 'invalid_amount', 'fraction refused')
check(select(2, goals.validate('total', nil, 0, allowed)) == 'invalid_amount', 'zero total refused')
check(select(2, goals.validate('banana', nil, nil, allowed)) == 'invalid_goal', 'unknown mode refused')

-- validate: a total goal counts every allowed item
goal = goals.validate('total', nil, 200, allowed)
check(goal and goal.mode == 'total' and goal.amount == 200, 'total goal kept')
check(#goal.items == 2, 'total goal lists the farm items')

-- progress: per-item needs every item done; withdrawals subtract
goal = goals.validate('each', { farm_test1 = 100, farm_test2 = 50 }, nil, allowed)
local progress = goals.progress(goal, {
    farm_test1 = { deposited = 120, withdrawn = 20 },
    farm_test2 = { deposited = 25, withdrawn = 0 },
})
check(progress.deposited == 145 and progress.withdrawn == 20, 'both counters summed')
check(progress.net == 125, 'net is deposited - withdrawn')
near(progress.percent, 0.5, 'percent is the worst item')
check(not progress.complete, 'not complete until every item is done')

progress = goals.progress(goal, {
    farm_test1 = { deposited = 100, withdrawn = 0 },
    farm_test2 = { deposited = 50, withdrawn = 0 },
})
check(progress.complete and progress.percent == 1, 'complete when every item is done')

-- progress: taking more out than in goes negative and clamps the bar at zero
progress = goals.progress(goal, { farm_test1 = { deposited = 10, withdrawn = 60 } })
check(progress.net == -50, 'net can go negative')
near(progress.percent, 0, 'bar clamps at zero')

-- progress: a total goal mixes the items
goal = goals.validate('total', nil, 200, allowed)
progress = goals.progress(goal, {
    farm_test1 = { deposited = 100, withdrawn = 0 },
    farm_test2 = { deposited = 150, withdrawn = 50 },
})
check(progress.net == 200 and progress.complete, 'total mode sums every farm item')
near(progress.percent, 1, 'total percent capped at 1')

-- progress: no counters at all
progress = goals.progress(goal, {})
check(progress.net == 0 and progress.percent == 0 and not progress.complete, 'empty counters')

print('goals ok')
