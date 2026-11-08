-- Fishing levels (1-30) and the skill tree. Pure functions, used by the server, the client and the unit tests.
local levels = {}

levels.max = 30

---Total XP needed to reach a level.
---@param level integer
---@return integer
function levels.xpFor(level)
    if level <= 1 then return 0 end

    return math.floor(100 * (level - 1) ^ 1.9 + 0.5)
end

---@param xp integer
---@return integer
function levels.fromXp(xp)
    local level = 1

    while level < levels.max and xp >= levels.xpFor(level + 1) do
        level = level + 1
    end

    return level
end

---Skill points a level gives in all (one per level from 2).
---@param level integer
---@return integer
function levels.points(level)
    return math.max(0, level - 1)
end

-- The tree. Each branch's nodes are in order; a node needs at least one rank in the one before it.
-- values[rank] is the total effect at that rank. A capstone costs `cost` points, needs `needs` points spent in its
-- branch, and only one capstone may be taken.
levels.branches = {
    {
        id = 'merchant',
        nodes = {
            { id = 'price', values = { 0.05, 0.10, 0.15 } },
            { id = 'demand', values = { 0.25, 0.5 } },
            { id = 'discount', values = { 0.10, 0.20 } },
            { id = 'prizes', values = { 0.25 } },
        },
        capstone = { id = 'fishmonger', cost = 3, needs = 8, value = 0.25 },
    },
    {
        id = 'hunter',
        nodes = {
            { id = 'bar', values = { 8, 16, 24 } },
            { id = 'wait', values = { 0.10, 0.20 } },
            { id = 'treasure', values = { 0.05, 0.10 } },
            { id = 'rare', values = { 0.10, 0.20 } },
            { id = 'legendary', values = { 0.0005, 0.001, 0.0015 } },
            { id = 'sonar', values = { 1 } },
        },
        capstone = { id = 'seeker', cost = 3, needs = 8, value = 2 },
    },
    {
        id = 'trapper',
        nodes = {
            { id = 'pots', values = { 1, 2, 3 } },
            { id = 'speed', values = { 0.15, 0.30 } },
            { id = 'junk', values = { 0.05, 0.10 } },
            { id = 'saver', values = { 0.30 } },
        },
        capstone = { id = 'mariner', cost = 3, needs = 8, value = 1 },
    },
}

local branchOf = {}
local nodeOf = {}

for _, branch in ipairs(levels.branches) do
    for index, node in ipairs(branch.nodes) do
        branchOf[node.id] = branch
        nodeOf[node.id] = { node = node, index = index }
    end

    branchOf[branch.capstone.id] = branch
end

---Points spent in a set of skills, in total and in one branch.
---@param skills table<string, integer>
---@param branch? table
---@return integer
function levels.spent(skills, branch)
    local total = 0

    for id, rank in pairs(skills) do
        local owner = branchOf[id]

        if owner and (not branch or owner == branch) then
            total = total + (owner.capstone.id == id and owner.capstone.cost or rank)
        end
    end

    return total
end

---Whether one more rank of a skill can be bought, and why not.
---@param skills table<string, integer>
---@param level integer
---@param id string
---@return boolean ok
---@return string? reason
function levels.canLearn(skills, level, id)
    local branch = branchOf[id]
    if not branch then return false, 'invalid' end

    local free = levels.points(level) - levels.spent(skills)

    if branch.capstone.id == id then
        if skills[id] then return false, 'maxed' end

        for _, other in ipairs(levels.branches) do
            if skills[other.capstone.id] then return false, 'one_capstone' end
        end

        if levels.spent(skills, branch) < branch.capstone.needs then return false, 'locked' end
        if free < branch.capstone.cost then return false, 'no_points' end

        return true
    end

    local entry = nodeOf[id]
    local rank = skills[id] or 0

    if rank >= #entry.node.values then return false, 'maxed' end
    if entry.index > 1 and not skills[branch.nodes[entry.index - 1].id] then return false, 'locked' end
    if free < 1 then return false, 'no_points' end

    return true
end

---The effect of a skill at its current rank (0 when not learned).
---@param skills table<string, integer>
---@param id string
---@return number
function levels.value(skills, id)
    local rank = skills[id]
    if not rank then return 0 end

    local branch = branchOf[id]
    if branch and branch.capstone.id == id then return branch.capstone.value end

    local entry = nodeOf[id]

    return entry and entry.node.values[rank] or 0
end

---Drops unknown ids and impossible ranks (from a hand-edited row).
---@param skills unknown
---@return table<string, integer>
function levels.clean(skills)
    local clean = {}
    if type(skills) ~= 'table' then return clean end

    for id, rank in pairs(skills) do
        local branch = branchOf[id]
        rank = math.tointeger(rank)

        if branch and rank and rank > 0 then
            local max = branch.capstone.id == id and 1 or #nodeOf[id].node.values
            clean[id] = math.min(rank, max)
        end
    end

    return clean
end

return levels
