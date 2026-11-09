dofile('harness.lua')

local levels = require 'shared.levels'

-- Same curve as fishing
check(levels.xpFor(2) == 100)
check(levels.fromXp(10 ^ 9) == 30, 'capped at 30')
check(levels.points(30) == 29)

-- Four branches of 9 ranks each, so 29 points can't take everything
check(#levels.branches == 4, 'four branches')
for _, branch in ipairs(levels.branches) do
    local ranks = 0
    for _, node in ipairs(branch.nodes) do ranks = ranks + #node.values end
    check(ranks == 9, ('%s has 9 ranks'):format(branch.id))
end

-- Order inside a branch and the capstone rules
local skills = {}
check(select(2, levels.canLearn(skills, 5, 'extra_ore')) == 'locked', 'needs speed first')
skills.speed, skills.extra_ore, skills.wear, skills.coal = 3, 2, 2, 1
check(levels.spent(skills) == 8)
check(select(2, levels.canLearn(skills, 10, 'master_miner')) == 'no_points', 'capstone costs 3')
check(levels.canLearn(skills, 12, 'master_miner'), 'capstone open with 8 points and 3 free')
skills.master_miner = 1
check(levels.value(skills, 'master_miner') == 1)

skills.geode, skills.gems, skills.tracking, skills.rare = 3, 2, 1, 2
check(select(2, levels.canLearn(skills, 30, 'gemologist')) == 'one_capstone', 'only one capstone')

check(levels.value(skills, 'speed') == 0.15)
check(levels.value(skills, 'golden_pan') == 0)

print('levels ok')
