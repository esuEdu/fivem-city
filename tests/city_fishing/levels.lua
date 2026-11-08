dofile('harness.lua')

local levels = require 'shared.levels'

-- XP curve
check(levels.xpFor(1) == 0, 'level 1 needs no XP')
check(levels.xpFor(2) == 100, 'level 2 needs 100 XP')
check(levels.fromXp(0) == 1)
check(levels.fromXp(99) == 1)
check(levels.fromXp(100) == 2)
check(levels.fromXp(10 ^ 9) == 30, 'capped at 30')

for level = 2, 30 do
    check(levels.xpFor(level) > levels.xpFor(level - 1), 'curve goes up')
    check(levels.fromXp(levels.xpFor(level)) == level, 'exact XP gives the level')
end

check(levels.points(1) == 0 and levels.points(30) == 29)

-- Learning in order
local skills = {}
check(levels.canLearn(skills, 1, 'price') == false, 'no points at level 1')

local ok, reason = levels.canLearn(skills, 5, 'demand')
check(not ok and reason == 'locked', 'needs the node before it')

check(levels.canLearn(skills, 5, 'price'))
skills.price = 3
local maxed = select(2, levels.canLearn(skills, 10, 'price'))
check(maxed == 'maxed')

check(levels.value(skills, 'price') == 0.15)
check(levels.value(skills, 'demand') == 0)
check(levels.spent(skills) == 3)

-- Capstone: needs 8 points in its branch, and only one
local capReason = select(2, levels.canLearn(skills, 30, 'fishmonger'))
check(capReason == 'locked', 'capstone needs points in the branch')

skills.demand, skills.discount, skills.prizes = 2, 2, 1
check(levels.spent(skills) == 8)
check(levels.canLearn(skills, 12, 'fishmonger'), 'capstone open with 8 points and 3 free')
skills.fishmonger = 1
check(levels.spent(skills) == 11)
check(levels.value(skills, 'fishmonger') == 0.25)

local hunter = { bar = 3, wait = 2, treasure = 2, rare = 1 }
for id, rank in pairs(hunter) do skills[id] = rank end
local oneCap = select(2, levels.canLearn(skills, 30, 'seeker'))
check(oneCap == 'one_capstone', 'only one capstone')

-- Not enough free points
local poor = { price = 1 }
check(select(2, levels.canLearn(poor, 2, 'demand')) == 'no_points')

-- Cleaning a hand-edited row
local clean = levels.clean({ price = 9, nope = 1, fishmonger = 4, demand = 'x', bar = 0 })
check(clean.price == 3 and clean.nope == nil and clean.fishmonger == 1 and clean.demand == nil and clean.bar == nil)

print('levels ok')
