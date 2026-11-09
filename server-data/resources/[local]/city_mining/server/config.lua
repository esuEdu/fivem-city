-- Server-only mining settings: drops, chances, prices, timers. Numbers come from the design doc (docs/city-mining.md).
return {
    -- Veins by tier. ores: what the vein is (picked by weight when it spawns); amount: ore per vein;
    -- extras: bonus drops; gems: chance of one rough gem; geodes: chance per vein, checked in order.
    tiers = {
        {
            ores = { { item = 'copper_ore', weight = 55 }, { item = 'iron_ore', weight = 45 } },
            amount = { 2, 5 },
            xp = 10,
            respawn = 240,
            extras = { { item = 'coal', chance = 0.35, count = { 1, 2 } } },
            geodes = { { item = 'geode', chance = 0.03 } },
        },
        {
            ores = { { item = 'silver_ore', weight = 60 }, { item = 'quartz', weight = 40 } },
            amount = { 2, 4 },
            xp = 14,
            respawn = 360,
            extras = { { item = 'saltpeter', chance = 0.30, count = { 1, 2 } } },
            geodes = { { item = 'geode', chance = 0.03 } },
        },
        {
            ores = { { item = 'gold_ore', weight = 100 } },
            amount = { 1, 3 },
            xp = 20,
            respawn = 600,
            extras = {},
            gems = { chance = 0.06, list = { { item = 'rough_emerald', weight = 45 }, { item = 'rough_ruby', weight = 40 }, { item = 'rough_diamond', weight = 15 } } },
            geodes = { { item = 'deep_geode', chance = 0.04 }, { item = 'geode', chance = 0.02 } },
        },
        {
            ores = { { item = 'platinum_ore', weight = 100 } },
            amount = { 1, 3 },
            xp = 28,
            respawn = 900,
            extras = {},
            gems = { chance = 0.08, list = { { item = 'rough_emerald', weight = 35 }, { item = 'rough_ruby', weight = 35 }, { item = 'rough_diamond', weight = 30 } } },
            geodes = { { item = 'ancient_geode', chance = 0.05 }, { item = 'deep_geode', chance = 0.02 } },
        },
    },

    mining = {
        minSeconds = Config.Minigame.minSeconds, -- start to finish at base speed (the minigame takes about 15 s)
        maxSeconds = 120,
        range = 3.5,       -- metres from the vein
        perfectBonus = 0.05, -- per perfect strike: chance to roll the top of the range
        allPerfect = { ore = 1, geode = 0.01 },
        -- Diminishing returns: veins mined in the last hour
        softCap = 80,      -- above it, extra ore and geode chances are halved
        hardCap = 120,     -- above it, a vein only gives the minimum
    },

    -- Rotation: a depleted point waits this long before it can hold a vein again
    pointCooldown = 60,

    superRocks = {
        checkMinutes = 30,
        chance = 0.4,
        amount = { 15, 25 },
        geodeChance = 0.25,
        xp = 60,
        range = 8.0, -- a dynamite this close breaks it
    },

    -- Sell prices before demand (NPC). Ingots are the stamped price.
    prices = {
        coal = 12, copper_ore = 15, iron_ore = 20, quartz = 30, saltpeter = 35, silver_ore = 40, gold_nugget = 60,
        gold_ore = 90, platinum_ore = 180,
        copper = 95, iron = 115, steel = 300, silver_bar = 210, goldbar = 780, platinum_bar = 1950,
    },
    unstampedShare = 0.6,

    market = { dropPerOre = 0.003, dropPerIngot = 0.01, floor = 0.5, recoverPerMinute = 0.01, range = 4.0 },

    -- Smelting. inputs are taken from the inventory; at the public smelter ingots used as inputs must be stamped.
    recipes = {
        copper = { inputs = { { 'copper_ore', 4 } }, coal = 1, seconds = 20, fee = 5, xp = 0, home = true },
        iron = { inputs = { { 'iron_ore', 4 } }, coal = 1, seconds = 30, fee = 6, xp = 0, home = true },
        steel = { inputs = { { 'iron', 2 } }, coal = 2, seconds = 60, fee = 15, xp = 3, home = true },
        silver_bar = { inputs = { { 'silver_ore', 4 } }, coal = 1, seconds = 45, fee = 10, xp = 3 },
        goldbar = { inputs = { { 'gold_ore', 4 }, { 'silver_bar', 1 } }, coal = 2, seconds = 90, fee = 40, xp = 6 },
        platinum_bar = { inputs = { { 'platinum_ore', 4 }, { 'goldbar', 1 } }, coal = 2, seconds = 120, fee = 100, xp = 10 },
        gunpowder = { inputs = { { 'saltpeter', 3 } }, coal = 1, seconds = 30, homeOnly = true, xp = 0 },
        homemade_dynamite = { inputs = { { 'gunpowder', 2 }, { 'metalscrap', 1 } }, coal = 0, seconds = 60, homeOnly = true, xp = 0 },
    },
    -- Ingots the smelter stamps (the others it makes aren't ingots)
    ingots = { copper = true, iron = true, steel = true, silver_bar = true, goldbar = true, platinum_bar = true },

    smelter = { maxBatch = 50, homeMaxBatch = 10, homeSlowdown = 3, pickupHours = 48, range = 4.0 },

    -- Geodes: fee to open at Vangelico, XP, and what's inside (one roll by weight)
    geodes = {
        geode = {
            fee = 50, xp = 5,
            loot = {
                { item = 'copper_ore', weight = 27, count = { 6, 10 } },
                { item = 'iron_ore', weight = 25, count = { 6, 10 } },
                { item = 'coal', weight = 15, count = { 4, 8 } },
                { item = 'silver_ore', weight = 12, count = { 3, 5 } },
                { item = 'quartz', weight = 10, count = { 3, 5 } },
                { item = 'rough_amethyst', weight = 6, count = { 1, 1 }, gem = true },
                { item = 'rough_topaz', weight = 5, count = { 1, 1 }, gem = true },
                { item = 'gold_nugget', weight = 3, count = { 2, 3 }, rare = true },
            },
        },
        deep_geode = {
            fee = 150, xp = 15,
            loot = {
                { item = 'iron_ore', weight = 15, count = { 8, 12 } },
                { item = 'silver_ore', weight = 20, count = { 8, 12 } },
                { item = 'gold_ore', weight = 20, count = { 5, 8 } },
                { item = 'rough_amethyst', weight = 10, count = { 1, 2 }, gem = true },
                { item = 'rough_topaz', weight = 8, count = { 1, 2 }, gem = true },
                { item = 'rough_emerald', weight = 12, count = { 1, 2 }, gem = true },
                { item = 'rough_ruby', weight = 10, count = { 1, 2 }, gem = true },
                { item = 'rough_diamond', weight = 3, count = { 1, 2 }, gem = true, rare = true },
                { item = 'gold_nugget', weight = 2, count = { 3, 5 } },
            },
        },
        ancient_geode = {
            fee = 400, xp = 30,
            loot = {
                { item = 'gold_ore', weight = 20, count = { 8, 12 } },
                { item = 'platinum_ore', weight = 20, count = { 6, 10 } },
                { item = 'rough_emerald', weight = 15, count = { 2, 3 }, gem = true },
                { item = 'rough_ruby', weight = 15, count = { 2, 3 }, gem = true },
                { item = 'rough_diamond', weight = 15, count = { 1, 3 }, gem = true, rare = true },
                { item = 'fossil', weight = 8, count = { 1, 1 }, rare = true },
                { item = 'ancient_coin', weight = 5, count = { 1, 1 }, rare = true },
                { item = 'old_relic', weight = 4, count = { 1, 1 }, rare = true },
                { item = 'mountain_heart', weight = 1, count = { 1, 1 }, rare = true },
            },
        },
    },

    -- Gems: rough price, the cut gem it becomes and its 1-star price
    gems = {
        rough_amethyst = { cut = 'amethyst', price = 80, cutPrice = 150 },
        rough_topaz = { cut = 'topaz', price = 100, cutPrice = 190 },
        rough_emerald = { cut = 'emerald', price = 300, cutPrice = 600 },
        rough_ruby = { cut = 'ruby', price = 350, cutPrice = 700 },
        rough_diamond = { cut = 'diamond', price = 900, cutPrice = 1800 },
    },
    cutting = {
        feeShare = 0.15,
        minutes = 5,
        breakChance = 0.08,
        gemologistBreak = 0.03,
        stars = { 0.6, 0.3, 0.1 },
        gemologistStars = { 0.4, 0.4, 0.2 },
        starPrice = { 1.0, 1.4, 2.0 },
        dust = 'gem_dust',
    },

    -- Jewellery made at Vangelico; price at 1 star (the gem's stars carry over)
    jewelry = {
        silver_ring = { inputs = { { 'silver_bar', 1 }, { 'amethyst', 1 } }, gem = 'amethyst', price = 500 },
        emerald_necklace = { inputs = { { 'goldbar', 1 }, { 'emerald', 1 } }, gem = 'emerald', price = 1650 },
        ruby_ring = { inputs = { { 'goldbar', 1 }, { 'ruby', 1 } }, gem = 'ruby', price = 1800 },
        goldchain = { inputs = { { 'goldbar', 2 } }, price = 1900 },
        rolex = { inputs = { { 'goldbar', 2 }, { 'topaz', 1 } }, gem = 'topaz', price = 2100 },
        diamond_ring = { inputs = { { 'goldbar', 1 }, { 'diamond', 1 } }, gem = 'diamond', price = 3000 },
        platinum_watch = { inputs = { { 'platinum_bar', 1 }, { 'diamond', 1 } }, gem = 'diamond', price = 4800 },
    },
    jewelryCraft = { fee = 150, minutes = 10 },

    -- Other things Vangelico buys
    collectibles = { gem_dust = 20, ancient_coin = 400, fossil = 600, old_relic = 800, mountain_heart = 15000 },

    jeweler = { range = 4.0 },

    -- Panning: the minigame, the gravel points and what a pan gives
    panning = {
        minSeconds = 12,
        maxSeconds = 90,
        range = 4.0,
        wait = 3,          -- seconds between pans
        respawn = 180,
        xp = 4,
        drops = {
            { item = 'metalscrap', weight = 35, count = { 1, 1 } },
            { item = 'copper_ore', weight = 13, count = { 1, 2 } },
            { item = 'iron_ore', weight = 12, count = { 1, 2 } },
            { item = 'silver_ore', weight = 10, count = { 1, 2 } },
            { item = 'gold_nugget', weight = 25, count = { 1, 1 }, nugget = true },
            { item = 'geode', weight = 3, count = { 1, 1 }, geode = true },
            { item = 'rough_amethyst', weight = 0.75, count = { 1, 1 }, rare = true },
            { item = 'rough_topaz', weight = 0.75, count = { 1, 1 }, rare = true },
            { item = 'ancient_coin', weight = 0.3, count = { 1, 1 }, rare = true },
            { item = 'old_relic', weight = 0.2, count = { 1, 1 }, rare = true },
        },
    },
    sluice = { cycleSeconds = 30, maxMinutes = 60, range = 15.0, xp = 2 },

    -- Dynamite, the passage and cave-ins
    dynamite = {
        passageMinutes = 20,
        passageRange = 8.0,
        homemadeFail = 0.10,
        failDamage = 60,
        throwRange = 25.0, -- the blast must be this close to the player who set it
    },
    caveIns = {
        checkMinutes = 10,
        chance = 0.05,
        afterBlast = 0.25,
        blastSeconds = 180,
        warningSeconds = 8,
        damage = 40,
        helmetDamage = 15,
        trappedSeconds = 60,
        rescueRange = 3.0,
    },

    -- Hidden luck of the day, multiplies rare, geode, gem, nugget and 3-star chances
    luck = { min = -0.2, max = 0.3 },

    -- Safety gear effects
    ppe = { gloves = 0.25, boots = 1.1 },

    respec = { price = 5000 },

    -- Crime buyer: moves every day between these points (check them in game)
    crime = {
        points = {
            vec4(2343.6, 3127.4, 48.2, 80.0),
            vec4(1543.2, 2177.9, 79.0, 270.0),
            vec4(2678.4, 3509.6, 52.7, 60.0),
        },
        unstamped = 1.1,
        gunpowder = 90,
        dynamite = 1500,
        valuables = 0.5,
        range = 4.0,
    },
}
