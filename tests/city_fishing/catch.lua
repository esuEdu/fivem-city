dofile('harness.lua')

Config.Minigame = { height = 568, barBase = 96, barPerLevel = 5, start = 0.3, gain = 0.12, loss = 0.17 }

local catch = require 'server.catch'
local fish = require 'server.fish'
local settings = require 'server.config'
local gear = require 'shared.gear'

local function ctx(extra)
    local base = {
        region = 'ocean', shore = 3, level = 1, skills = {}, effects = gear.tackleEffects({}), hour = 12,
        weather = 'CLEAR', atSpot = function() return false end,
    }
    for k, v in pairs(extra or {}) do base[k] = v end
    return base
end

-- Weather and hours
check(catch.weatherMatches(nil, 'RAIN'))
check(catch.weatherMatches('rain', 'THUNDER'))
check(not catch.weatherMatches('rain', 'CLEAR'))
check(catch.weatherMatches('storm', 'thunder'))
check(catch.weatherMatches('clear', 'EXTRASUNNY'))
check(not catch.weatherMatches('clear', 'FOGGY'))
check(catch.weatherMatches('fog', 'FOGGY'))

check(catch.hourMatches({ { 6, 19 } }, 6))
check(not catch.hourMatches({ { 6, 19 } }, 19))
check(catch.hourMatches({ { 18, 2 } }, 23) and catch.hourMatches({ { 18, 2 } }, 1))
check(not catch.hourMatches({ { 18, 2 } }, 2))

-- Bite wait: bait and frenzy shorten it, never under the floor
catch.random = function() return 1 end
local plain = catch.biteSeconds(ctx(), settings.wait)
local baited = catch.biteSeconds(ctx({ bait = gear.baits.bait_worm }), settings.wait)
local frenzy = catch.biteSeconds(ctx({ frenzy = 'fish_sardine' }), settings.wait)
check(baited < plain and frenzy < plain, 'bait and frenzy are faster')
catch.random = function() return 0 end
check(catch.biteSeconds(ctx({ bait = gear.baits.bait_deluxe, firstBite = true }), settings.wait) >= settings.wait.floor)

-- Picking: a failed roll on everything gives junk; a frenzy gives its species
catch.random = function() return 0.999 end
local junk = catch.pick(fish.list, ctx(), settings)
check(junk.junk, 'nothing passes -> junk')

catch.random = function() return 0.5 end
local frenzied = catch.pick(fish.list, ctx({ frenzy = 'fish_mackerel' }), settings)
check(frenzied.name == 'fish_mackerel', 'frenzy species')

-- Region and level gates
catch.random = function() return 0 end
for _ = 1, 20 do
    local entry = catch.pick(fish.list, ctx({ region = 'lake', level = 1 }), settings)
    check(entry.regionSet.lake, 'lake fish only')
    check(entry.minLevel <= 1, 'no fish above the level')
end

-- Legendary only at its spot, in its hours and weather
local function legendaryFound(extra)
    catch.random = function() return 0 end
    local entry = catch.pick(fish.list, ctx(extra), settings)
    return entry.legendary ~= nil
end

check(not legendaryFound({ region = 'canal', hour = 1, weather = 'RAIN' }), 'not off the spot')
check(legendaryFound({ region = 'canal', hour = 1, weather = 'RAIN', atSpot = function(id) return id == 'canal_leviathan' end }), 'at the spot')
check(not legendaryFound({ region = 'canal', hour = 12, weather = 'RAIN', atSpot = function() return true end }), 'not out of hours')

-- Legendary chance stays tiny and capped
local low = catch.legendaryChance(ctx({ level = 1 }), settings.legendary)
local high = catch.legendaryChance(ctx({ level = 30, skills = { legendary = 3, seeker = 1 }, effects = { curiosity = true } }), settings.legendary)
check(low < 0.002, 'base chance is tiny')
check(high > low and high <= settings.legendary.maxChance * 2, 'skills raise it, capped')

-- Size, stars and XP
local sardine = fish.byName.fish_sardine
check(catch.size(sardine, 0, 0, false) == sardine.size[1] + 1)
check(catch.size(sardine, 1, 0, false) == sardine.size[2], 'imperfect catch never passes the max')
check(catch.size(sardine, 1, 0, true) == sardine.size[2] + 1, 'perfect can reach max + 1')
check(catch.size(sardine, 1, 100, true) == sardine.size[1], 'shrinks to the minimum')

check(catch.stars(0.1, 0, false) == 1)
check(catch.stars(0.1, 0, true) == 1, 'perfect does not raise 1 star')
check(catch.stars(0.5, 0, true) == 3)
check(catch.stars(0.9, 2, true) == 4, 'capped at 4')

local legendary = fish.byName.fish_golden_marlin
check(catch.xp(fish.byName.junk_can) == 3)
check(catch.xp(legendary, 1, false, false) > catch.xp(sardine, 1, false, false) * 5)
check(catch.xp(sardine, 1, true, true) > catch.xp(sardine, 1, false, false))

-- Bar size and the fastest plausible catch
check(catch.bar(ctx({ level = 1 }), Config.Minigame) == 101)
check(catch.bar(ctx({ level = 30, skills = { bar = 3 }, effects = { bar = 48 }, bait = gear.baits.bait_deluxe }), Config.Minigame) == 284, 'capped at half the track')
check(catch.minMs(Config.Minigame) == 5833)

-- Every fish entry is complete
for _, entry in ipairs(fish.list) do
    check(type(entry.label) == 'string' and #entry.regions > 0 and #entry.hours > 0, entry.name)
    if entry.kind == 'fish' then
        check(entry.difficulty and entry.behavior and entry.size and entry.price, entry.name)
    end
end

-- Tackle stacks
local effects = gear.tackleEffects({ { name = 'tackle_cork' }, { name = 'tackle_cork' }, { name = 'tackle_sonar' } })
check(effects.bar == 48 and effects.sonar == true)

print('catch ok')
