-- Server-only fishing settings: rewards, chances, secret spots and schedules players must not read.
return {
    -- Each cast takes this much hunger and thirst (0-100); under minStatus the player is too weak to cast
    cast = { hunger = 0.4, thirst = 0.4, minStatus = 10, cooldownMs = 1500 },

    -- Bite wait in seconds (research section 3) and how much each level takes off the maximum
    wait = { min = 0.6, max = 30.0, perLevel = 0.5, firstBite = 0.25, floor = 0.5 },

    -- A result is refused this far (metres) from where the player cast, or after this many seconds
    session = { maxMove = 8.0, maxSeconds = 180, latencyMs = 1500 },

    -- Chest (research section 8)
    chest = { chance = 0.15 },

    -- Legendary fish: chance per bite when every condition matches
    legendary = { baseChance = 0.0015, perLevel = 0.0001, curiosity = 0.0005, deluxe = 0.0003, maxChance = 0.015 },

    -- Junk: extra chance taken off by the trapper's junk node only applies to pots; bait gives the fish list a second pass
    rareDifficulty = 60,

    -- Price by stars (1-4)
    quality = { 1.0, 1.25, 1.5, 2.0 },

    -- Fish market demand per species: drops for every fish sold, never under floor, recovers every minute
    market = { dropPerFish = 0.005, floor = 0.45, recoverPerMinute = 0.01, sellRange = 4.0 },

    -- Crab pots
    pots = { minutes = 45, max = 3, expireHours = 48, junk = 0.2, pullRange = 6.0, placeRange = 8.0, xp = 5 },

    -- Boat rental
    boat = { model = `suntrap`, deposit = 1500, fee = 250 },

    -- Skill reset at the shop
    respec = { price = 5000 },

    -- Frenzy: every checkMinutes, chance to start at one of the spots for 15-30 minutes
    frenzy = {
        checkMinutes = 20,
        chance = 0.25,
        minutes = { 15, 30 },
        spots = {
            { coords = vec3(-1850.0, -1270.0, 0.0), radius = 60.0, region = 'ocean' },
            { coords = vec3(-3426.0, 967.0, 0.0), radius = 60.0, region = 'ocean' },
            { coords = vec3(-280.0, 6650.0, 0.0), radius = 60.0, region = 'ocean' },
            { coords = vec3(1500.0, 4000.0, 30.0), radius = 80.0, region = 'alamo' },
            { coords = vec3(1950.0, 350.0, 160.0), radius = 70.0, region = 'lake' },
            { coords = vec3(-2200.0, 2700.0, 0.0), radius = 60.0, region = 'river' },
            { coords = vec3(-1100.0, -2700.0, 0.0), radius = 150.0, region = 'deep' },
        },
    },

    -- Tournaments: on a schedule (wday 1 = Sunday, server clock) and opened by staff (staffAce) from the app.
    -- mode: biggest (one species or any), count (most fish), weight (total kg). prizes: cash for 1st, 2nd, 3rd.
    tournaments = {
        staffAce = 'group.mod',
        maxMinutes = 120,
        prizes = { 5000, 2500, 1000 },
        schedule = {
            { wday = 7, hour = 20, minutes = 60, mode = 'biggest', region = 'ocean', label = 'Saturday Pier Classic' },
            { wday = 4, hour = 21, minutes = 45, mode = 'count', region = 'lake', label = 'Midweek Lake Rush' },
        },
    },

    -- Chest loot: rolled `rolls` times, each entry by weight; minShore/minLevel gate it. count = { min, max }
    loot = {
        rolls = { 1, 3 },
        items = {
            { item = 'bait_worm', weight = 30, count = { 3, 10 } },
            { item = 'bait_deluxe', weight = 12, count = { 2, 5 }, minLevel = 9 },
            { item = 'bait_magnet', weight = 4, count = { 1, 3 }, minLevel = 16 },
            { item = 'metalscrap', weight = 25, count = { 2, 8 } },
            { item = 'copper', weight = 18, count = { 2, 6 } },
            { item = 'iron', weight = 12, count = { 1, 4 }, minShore = 3 },
            { item = 'goldchain', weight = 4, count = { 1, 1 }, minShore = 3 },
            { item = 'fishing_pearl', weight = 3, count = { 1, 1 }, minShore = 4 },
            { item = 'diamond_ring', weight = 1, count = { 1, 1 }, minShore = 5, minLevel = 15 },
            { item = 'tackle_spinner', weight = 3, count = { 1, 1 }, minLevel = 12 },
            { item = 'tackle_treasure', weight = 2, count = { 1, 1 }, minLevel = 15 },
            { item = 'tackle_quality', weight = 1, count = { 1, 1 }, minLevel = 20 },
        },
    },

    -- How much one fish weighs on average per cm of length, for the weight tournaments (kg = (cm / 10) ^ 3 * factor)
    weightFactor = 0.012,
}
