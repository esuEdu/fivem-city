dofile('harness.lua')

vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
Config.Minigame = { minSeconds = 12 }
Config.Regions = {}

local rolls = require 'server.rolls'
local settings = require 'server.config'

local noSkills = function() return 0 end

---@param overrides table?
local function ctx(overrides)
    local base = { perfect = 0, strikes = 5, luck = 0, mined = 0, skill = noSkills, settings = settings }
    for key, value in pairs(overrides or {}) do base[key] = value end

    return base
end

local function countOf(drops, item)
    local total = 0
    for _, drop in ipairs(drops) do
        if drop.item == item then total = total + drop.count end
    end

    return total
end

local tier1 = settings.tiers[1]

-- Weighted pick and ranges
check(rolls.weighted({ { weight = 1, id = 'a' }, { weight = 3, id = 'b' } }, sequence({ 0.1 })).id == 'a')
check(rolls.weighted({ { weight = 1, id = 'a' }, { weight = 3, id = 'b' } }, sequence({ 0.9 })).id == 'b')
check(rolls.between(sequence({ 0 }), 2, 5) == 2)
check(rolls.between(sequence({ 0.999 }), 2, 5) == 5)

-- A plain T1 vein: the low end, no extras when every roll misses
local plain = rolls.vein(tier1, 'copper_ore', ctx(), sequence({ 0, 0.99 }))
check(countOf(plain, 'copper_ore') == 2, 'low end of 2-5')
check(#plain == 1, 'nothing else')

-- Five perfect strikes: top of the range (the roll hits), +1 ore
local perfect = rolls.vein(tier1, 'copper_ore', ctx({ perfect = 5 }), sequence({ 0, 0.1, 0.99 }))
check(countOf(perfect, 'copper_ore') == 6, 'top 5 + 1 for all perfect')

-- Master Miner adds one
local master = rolls.vein(tier1, 'copper_ore', ctx({ skill = function(id) return id == 'master_miner' and 1 or 0 end }), sequence({ 0, 0.99 }))
check(countOf(master, 'copper_ore') == 3)

-- Above the hard cap a vein gives only the minimum and nothing else
local tired = rolls.vein(tier1, 'copper_ore', ctx({ mined = 120, perfect = 5 }), sequence({ 0 }))
check(countOf(tired, 'copper_ore') == 2 and #tired == 1, 'hard cap: minimum only')

-- A geode when its roll is under the chance
local lucky = rolls.vein(tier1, 'copper_ore', ctx(), sequence({ 0, 0.99, 0.99, 0.99, 0.01 }))
check(countOf(lucky, 'geode') == 1, 'geode at 1% roll vs 3%')

-- Gems only on tiers that have them
local tier3 = settings.tiers[3]
local gem = rolls.vein(tier3, 'gold_ore', ctx(), sequence({ 0, 0.99, 0.99, 0.01, 0.1, 0.99, 0.99 }))
check(countOf(gem, 'rough_emerald') == 1, 'tier 3 gem')

-- Pans: golden pan doubles nuggets
local nuggetCtx = { luck = 0, skill = function(id) return id == 'golden_pan' and 2 or 0 end }
local drops = settings.panning.drops
-- metalscrap 35, copper 13, iron 12, silver 10 -> 70; nugget covers 70-95 of 100
local nugget = rolls.pan(drops, nuggetCtx, sequence({ 0.75, 0 }))
check(nugget.item == 'gold_nugget' and nugget.count == 2, 'golden pan doubles nuggets')

-- Cutting: break, then stars
local cutting = settings.cutting
check(rolls.cut(cutting, false, 0, sequence({ 0.01 })) == 0, 'breaks under 8%')
check(rolls.cut(cutting, false, 0, sequence({ 0.5, 0.05 })) == 3, '3 stars under 10%')
check(rolls.cut(cutting, false, 0, sequence({ 0.5, 0.3 })) == 2, '2 stars')
check(rolls.cut(cutting, false, 0, sequence({ 0.5, 0.9 })) == 1, '1 star')
check(rolls.cut(cutting, true, 0, sequence({ 0.05, 0.9 })) == 1, 'gemologist breaks only under 3%')

-- Geodes give something from their table
for name, geode in pairs(settings.geodes) do
    local drop = rolls.geode(geode, { luck = 0, skill = noSkills }, sequence({ 0.5, 0.5 }))
    check(drop.item and drop.count >= 1, name)
end

print('rolls ok')
