-- Pure rolls: what a vein, a pan, a geode or a cut gives. No game calls, so tests/city_mining can run them with a fixed
-- random source. rand() returns a number in [0, 1).
local rolls = {}

---@param rand function
---@param low integer
---@param high integer
---@return integer
local function between(rand, low, high)
    if high <= low then return low end

    return low + math.floor(rand() * (high - low + 1))
end

rolls.between = between

---One entry by weight.
---@param list { weight: number }[]
---@param rand function
---@return table?
function rolls.weighted(list, rand)
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.weight end
    if total <= 0 then return end

    local pick = rand() * total

    for _, entry in ipairs(list) do
        pick = pick - entry.weight
        if pick < 0 then return entry end
    end

    return list[#list]
end

---@param chance number
---@return number clamped to [0, 1]
local function clamp(chance)
    return math.max(0, math.min(1, chance))
end

---What one vein gives.
---ctx: perfect (0-5 perfect strikes), strikes (max), luck (-0.2..0.3), mined (veins in the last hour),
---skill(id) -> value, settings (server config).
---@param tier table settings.tiers[n]
---@param ore string the vein's ore
---@param ctx table
---@param rand function
---@return { item: string, count: integer }[] drops
function rolls.vein(tier, ore, ctx, rand)
    local mining = ctx.settings.mining
    local soft = ctx.mined >= mining.softCap
    local hard = ctx.mined >= mining.hardCap
    local luck = ctx.luck or 0
    local skill = ctx.skill
    local drops = {}

    local low, high = tier.amount[1], tier.amount[2]
    if luck >= 0.2 then high = high + 1 elseif luck <= -0.15 then high = math.max(low, high - 1) end

    local count
    if hard then
        count = low
    else
        count = between(rand, low, high)

        if rand() < clamp(ctx.perfect * mining.perfectBonus) then count = high end

        local extra = skill('extra_ore')
        if soft then extra = extra / 2 end
        if rand() < extra then count = count + 1 end

        if ctx.perfect >= ctx.strikes then count = count + mining.allPerfect.ore end
        count = count + skill('master_miner')
    end

    drops[#drops + 1] = { item = ore, count = count }

    if hard then return drops end

    for _, extra in ipairs(tier.extras or {}) do
        if rand() < clamp(extra.chance * (1 + skill('coal'))) then
            drops[#drops + 1] = { item = extra.item, count = between(rand, extra.count[1], extra.count[2]) }
        end
    end

    if tier.gems and rand() < clamp(tier.gems.chance * (1 + skill('gems')) * (1 + skill('rare')) * (1 + luck)) then
        local gem = rolls.weighted(tier.gems.list, rand)
        if gem then drops[#drops + 1] = { item = gem.item, count = 1 } end
    end

    local geodeBonus = ctx.perfect >= ctx.strikes and mining.allPerfect.geode or 0

    for _, geode in ipairs(tier.geodes or {}) do
        local chance = (geode.chance + geodeBonus) * (1 + skill('geode')) * (1 + luck)
        if soft then chance = chance / 2 end

        if rand() < clamp(chance) then
            drops[#drops + 1] = { item = geode.item, count = 1 }
            break
        end
    end

    return drops
end

---What a super rock gives: lots of the region's ore and a good geode chance.
---@param tier table
---@param ore string
---@param super table settings.superRocks
---@param luck number
---@param rand function
---@return { item: string, count: integer }[]
function rolls.superRock(tier, ore, super, luck, rand)
    local drops = { { item = ore, count = between(rand, super.amount[1], super.amount[2]) } }
    local geode = tier.geodes and tier.geodes[1]

    if geode and rand() < clamp(super.geodeChance * (1 + luck)) then
        drops[#drops + 1] = { item = geode.item, count = 1 }
    end

    return drops
end

---What one pan (or one sluice cycle) gives. Nuggets, geodes and rare finds scale with skills and luck.
---@param drops table[] settings.panning.drops
---@param ctx table luck, skill(id)
---@param rand function
---@return { item: string, count: integer }
function rolls.pan(drops, ctx, rand)
    local luck = ctx.luck or 0
    local skill = ctx.skill
    local weighted = {}

    for _, entry in ipairs(drops) do
        local weight = entry.weight
        if entry.nugget then weight = weight * (1 + skill('nugget')) * (1 + luck) end
        if entry.geode then weight = weight * (1 + skill('river_geode')) * (1 + luck) end
        if entry.rare then weight = weight * (1 + skill('rare')) * (1 + luck) end
        weighted[#weighted + 1] = { weight = weight, entry = entry }
    end

    local pick = rolls.weighted(weighted, rand).entry
    local count = between(rand, pick.count[1], pick.count[2])

    if pick.nugget then count = count * math.max(1, skill('golden_pan')) end

    return { item = pick.item, count = count }
end

---What a geode holds. Gems and rare finds scale with luck and the Geologist's rare node.
---@param geode table settings.geodes[name]
---@param ctx table luck, skill(id)
---@param rand function
---@return { item: string, count: integer }
function rolls.geode(geode, ctx, rand)
    local luck = ctx.luck or 0
    local weighted = {}

    for _, entry in ipairs(geode.loot) do
        local weight = entry.weight
        if entry.gem or entry.rare then weight = weight * (1 + ctx.skill('rare')) * (1 + luck) end
        weighted[#weighted + 1] = { weight = weight, entry = entry }
    end

    local pick = rolls.weighted(weighted, rand).entry

    return { item = pick.item, count = between(rand, pick.count[1], pick.count[2]) }
end

---A cut: 0 = broken, else 1-3 stars.
---@param cutting table settings.cutting
---@param gemologist boolean
---@param luck number
---@param rand function
---@return integer
function rolls.cut(cutting, gemologist, luck, rand)
    local breakChance = gemologist and cutting.gemologistBreak or cutting.breakChance
    if rand() < breakChance then return 0 end

    local shares = gemologist and cutting.gemologistStars or cutting.stars
    local three = clamp(shares[3] * (1 + luck))
    local two = shares[2]
    local pick = rand()

    if pick < three then return 3 end
    if pick < three + two then return 2 end

    return 1
end

---Price after demand and stars, never negative.
---@param base number
---@param factor number
---@return integer
function rolls.price(base, factor)
    return math.max(0, math.floor(base * factor + 0.5))
end

return rolls
