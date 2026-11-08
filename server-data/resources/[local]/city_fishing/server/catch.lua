-- The rules of a catch (research sections 3-6 and 10): bite wait, what bites, chest, size, stars and XP.
-- Pure functions over a context table, so the unit tests can run them with a fixed random source.
local levels = require 'shared.levels'

local catch = {}

catch.random = math.random

local RAIN = { RAIN = true, THUNDER = true, CLEARING = true }
local SNOW = { SNOW = true, SNOWLIGHT = true, BLIZZARD = true, XMAS = true }

---Whether the weather fits a fish's condition.
---@param want string?
---@param weather string Renewed-Weathersync weather type (e.g. 'RAIN')
---@return boolean
function catch.weatherMatches(want, weather)
    if not want then return true end
    weather = tostring(weather or 'CLEAR'):upper()

    if want == 'rain' then return RAIN[weather] == true end
    if want == 'storm' then return weather == 'THUNDER' end
    if want == 'fog' then return weather == 'FOGGY' or weather == 'SMOG' end
    if want == 'clear' then return not RAIN[weather] and not SNOW[weather] and weather ~= 'FOGGY' end

    return false
end

---@param hours number[][]
---@param hour integer 0-23
---@return boolean
function catch.hourMatches(hours, hour)
    for _, window in ipairs(hours) do
        local from, to = window[1], window[2]

        if from <= to then
            if hour >= from and hour < to then return true end
        elseif hour >= from or hour < to then
            return true
        end
    end

    return false
end

---Seconds until a bite.
---@param ctx table
---@param settings table server config `wait`
---@return number
function catch.biteSeconds(ctx, settings)
    local min, max = settings.min, settings.max - ctx.level * settings.perLevel
    max = max - (ctx.effects.waitSeconds or 0)
    max = max * (1 - levels.value(ctx.skills, 'wait'))

    if ctx.firstBite then
        min, max = min * (1 - settings.firstBite), max * (1 - settings.firstBite)
    end

    if ctx.bait then
        min, max = min * (1 - ctx.bait.wait), max * (1 - ctx.bait.wait)
    end

    if ctx.frenzy then
        min, max = min / 2, max / 2
    end

    min = math.max(settings.floor, min)
    max = math.max(min, max)

    return min + (max - min) * catch.random()
end

---@param list table[]
---@return table[]
local function ordered(list)
    local copy = {}
    for i = 1, #list do copy[i] = { entry = list[i], tie = catch.random() } end

    table.sort(copy, function(a, b)
        if a.entry.precedence ~= b.entry.precedence then return a.entry.precedence < b.entry.precedence end
        return a.tie < b.tie
    end)

    for i = 1, #copy do copy[i] = copy[i].entry end

    return copy
end

---The legendary chance for this player (0 when not at the spot or out of conditions is decided by the caller).
---@param ctx table
---@param settings table server config `legendary`
---@return number
function catch.legendaryChance(ctx, settings)
    local chance = settings.baseChance + ctx.level * settings.perLevel + levels.value(ctx.skills, 'legendary')

    if ctx.effects.curiosity then chance = chance + settings.curiosity end
    if ctx.baitName == 'bait_deluxe' then chance = chance + settings.deluxe end

    chance = chance * math.max(1, levels.value(ctx.skills, 'seeker'))

    return math.min(chance, settings.maxChance * math.max(1, levels.value(ctx.skills, 'seeker')))
end

---Whether one entry passes every condition, before its chance roll.
---@param entry table
---@param ctx table
---@return boolean
local function eligible(entry, ctx)
    if not entry.regionSet[ctx.region] then return false end
    if ctx.level < entry.minLevel then return false end
    if not catch.hourMatches(entry.hours, ctx.hour) then return false end
    if not catch.weatherMatches(entry.weather, ctx.weather) then return false end
    if entry.legendary and not ctx.atSpot(entry.legendary) then return false end

    return true
end

---The chance roll for one entry (research 4.3).
---@param entry table
---@param ctx table
---@param settings table whole server config
---@return number
function catch.entryChance(entry, ctx, settings)
    if entry.legendary then return catch.legendaryChance(ctx, settings.legendary) end
    if entry.junk then return 1 end

    local chance = entry.chance
    local shore = ctx.shore + (ctx.frenzy and 1 or 0)

    if shore < entry.depth then
        chance = chance - entry.depthMult * chance * (entry.depth - shore)
    end

    chance = math.min(chance + ctx.level / 150, 0.9)

    if entry.kind == 'fish' and entry.difficulty >= settings.rareDifficulty then
        chance = chance * (1 + levels.value(ctx.skills, 'rare'))
        if ctx.effects.curiosity then chance = chance + 0.07 end
    end

    return math.max(0, chance)
end

---What bites. Bait lets the fish list be tried twice before junk.
---@param list table[] fish.list
---@param ctx table
---@param settings table whole server config
---@return table entry
function catch.pick(list, ctx, settings)
    local pool = {}
    for _, entry in ipairs(list) do
        if eligible(entry, ctx) then pool[#pool + 1] = entry end
    end

    -- A frenzy: only its species bites, unless something rarer is at a legendary spot
    if ctx.frenzy then
        for _, entry in ipairs(pool) do
            if entry.legendary and catch.random() < catch.entryChance(entry, ctx, settings) then return entry end
        end

        for _, entry in ipairs(pool) do
            if entry.name == ctx.frenzy then return entry end
        end
    end

    local passes = ctx.bait and 2 or 1
    local junk

    for _ = 1, passes do
        for _, entry in ipairs(ordered(pool)) do
            if entry.junk then
                junk = junk or entry
                break
            end

            if catch.random() < catch.entryChance(entry, ctx, settings) then return entry end
        end
    end

    if junk then return junk end

    for _, entry in ipairs(pool) do
        if entry.junk then return entry end
    end

    return pool[#pool]
end

---Whether a chest shows in this minigame.
---@param ctx table
---@param settings table server config `chest`
---@return boolean
function catch.rollChest(ctx, settings)
    local chance = settings.chance + (ctx.effects.treasure or 0) + levels.value(ctx.skills, 'treasure')
    if ctx.bait and ctx.bait.treasure then chance = chance + ctx.bait.treasure end

    return catch.random() < chance
end

---The size/quality factor from shore distance and level (research section 6), 0-1. Level 30 maps to 10.
---@param ctx table
---@return number
function catch.factor(ctx)
    local scaled = math.floor(ctx.level / 3)
    local even = scaled - scaled % 2

    if scaled < 10 then
        even = scaled + math.floor(catch.random() * (10 - scaled + 1))
        even = even - even % 2
    end

    local factor = (ctx.shore / 5) * ((even + 2) / 12) * (0.9 + catch.random() * 0.2)

    return math.max(0, math.min(1, factor))
end

---Size in cm. Time outside the bar shrinks it one cm per 0.8 s (research 5.3), never below the minimum.
---@param entry table
---@param factor number
---@param outsideSeconds number
---@param perfect boolean
---@return integer
function catch.size(entry, factor, outsideSeconds, perfect)
    local min, max = entry.size[1], entry.size[2]
    local size = math.floor(min + (max - min) * factor + 1)

    size = size - math.floor(math.max(0, outsideSeconds) / 0.8)
    if not perfect and size > max then size = max end

    return math.max(min, size)
end

---Stars 1-4.
---@param factor number
---@param qualityBonus integer quality bobbers
---@param perfect boolean
---@return integer
function catch.stars(factor, qualityBonus, perfect)
    local stars = factor < 0.33 and 1 or factor < 0.66 and 2 or 3
    stars = stars + qualityBonus

    if perfect and stars >= 2 then stars = stars + 1 end

    return math.min(4, stars)
end

---XP for a fish, using the stars before the perfect bonus.
---@param entry table
---@param stars integer
---@param chest boolean
---@param perfect boolean
---@return integer
function catch.xp(entry, stars, chest, perfect)
    if entry.kind ~= 'fish' then return 3 end

    local xp = stars * 3 + entry.difficulty / 3
    if chest then xp = math.floor(xp * 2.2) end
    if perfect then xp = math.floor(xp * 2.4) end
    if entry.legendary then xp = math.floor(xp * 5) end

    return math.floor(xp)
end

---Green bar size in minigame units.
---@param ctx table
---@param minigame table Config.Minigame
---@return integer
function catch.bar(ctx, minigame)
    local bar = minigame.barBase + minigame.barPerLevel * ctx.level + levels.value(ctx.skills, 'bar') + (ctx.effects.bar or 0)
    if ctx.bait and ctx.bait.bar then bar = bar + ctx.bait.bar end

    return math.min(math.floor(minigame.height / 2), bar)
end

---The fastest a fish can be caught, in ms: from the start progress to full, always inside the bar.
---@param minigame table Config.Minigame
---@return integer
function catch.minMs(minigame)
    return math.floor((1 - minigame.start) / minigame.gain * 1000)
end

return catch
