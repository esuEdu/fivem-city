lib.locale()

Config = {}

-- NPCs. Coordinates were placed without the game open: check them in game with /coords (city_base).
Config.Ped = `s_m_y_construct_01`
Config.JewelerPed = `u_f_y_jewelass_01`
Config.BuyerPed = `g_m_m_chicold_01`
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'
Config.PedDistance = 40.0

-- Mining supplies: licence, tools, safety gear, repairs, skill reset (Davis Quartz office)
Config.Shop = { coords = vec4(2952.6, 2747.5, 43.5, 280.0), blip = { sprite = 618, color = 5 } }

-- Public smelter and ore buyer (Stoner Cement Works)
Config.Smelter = { coords = vec4(1216.2, 1848.6, 79.0, 140.0), blip = { sprite = 436, color = 47 } }

-- Vangelico: opens geodes, cuts gems, makes jewellery, buys gems and jewellery
Config.Jeweler = { coords = vec4(-622.2, -229.9, 38.06, 305.0), blip = { sprite = 617, color = 5 } }

-- Regions. Their points (veins, gravel, the passage) are placed in game with /miningpoints and saved in the database;
-- the region's area is worked out from its points. tiers = share of each tier among the active veins.
-- kind 'vein' is mined with a pickaxe, 'gravel' is panned in a river.
Config.Regions = {
    { id = 'quarry', label = 'Davis Quartz', kind = 'vein', tiers = { 0.8, 0.2 }, active = 25, superRocks = true, blip = true },
    { id = 'senora', label = 'Grand Senora Canyons', kind = 'vein', tiers = { 0.6, 0.4 }, active = 15, superRocks = true },
    { id = 'tataviam', label = 'Tataviam Highlands', kind = 'vein', tiers = { 0, 1 }, active = 15, superRocks = true },
    { id = 'chaparral', label = 'Great Chaparral Mine', kind = 'vein', tiers = { 0, 0, 1 }, active = 10, gallery = true, passage = true },
    { id = 'gordo', label = 'Mount Gordo', kind = 'vein', tiers = { 0, 0, 1 }, active = 10 },
    { id = 'chianski', label = 'San Chianski', kind = 'vein', tiers = { 0, 0, 1 }, active = 10 },
    { id = 'chiliad', label = 'Mount Chiliad', kind = 'vein', tiers = { 0, 0, 0, 1 }, active = 8 },
    { id = 'cassidy', label = 'Cassidy Creek', kind = 'gravel', active = 4 },
    { id = 'raton', label = 'Raton Canyon', kind = 'gravel', active = 4 },
    { id = 'alamo', label = 'Alamo Sea', kind = 'gravel', active = 4 },
}

-- Vein looks per tier: rock models from the base game (the first one that exists is used) and the glow colour
-- drawn when the player is close. Check the models in game.
Config.Tiers = {
    { models = { `prop_rock_4_c`, `prop_rock_4_big2` }, light = { 255, 140, 60 } },
    { models = { `prop_rock_4_big2`, `prop_rock_4_c` }, light = { 220, 230, 255 } },
    { models = { `prop_rock_4_big`, `prop_rock_4_big2` }, light = { 255, 205, 60 } },
    { models = { `prop_rock_4_big`, `prop_rock_4_big2` }, light = { 190, 90, 255 } },
}
Config.SuperRockModel = { `prop_rock_4_big`, `prop_rock_4_big2` }
Config.PassageModel = { `prop_rock_4_big`, `prop_rock_4_big2` }
Config.GravelMarker = { 60, 170, 255 }

Config.SpawnDistance = 90.0 -- rocks are created (locally, never networked) only this close
Config.LightDistance = 15.0

-- Mining: pickaxe in hand and the timing minigame (web/index.html)
Config.Pickaxe = { prop = `prop_tool_pickaxe`, bone = 57005, offset = vec3(0.09, 0.03, -0.02), rotation = vec3(-78.0, 13.0, 28.0) }
Config.MineAnim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' }
Config.PanAnim = { dict = 'amb@world_human_bum_wash@male@low@idle_a', clip = 'idle_a' }
Config.PanProp = `prop_copper_pan`

-- Strikes: a marker sweeps the bar; pressing the key inside the zone is a hit, inside its centre a perfect hit
Config.Minigame = { strikes = 5, sweepSeconds = 1.1, zone = 0.22, perfect = 0.07, minSeconds = 12 }
-- Panning: keep the marker inside the band while the water drains
Config.PanGame = { seconds = 16, band = 0.26, drift = 0.55 }

Config.Keys = { action = 38 } -- E

-- Helmet lamp: a spot light from the head while the helmet is on
Config.HelmetProp = `prop_tool_hardhat`
Config.HelmetLight = { distance = 18.0, brightness = 6.0, radius = 22.0 }

-- The tablet app
Config.App = {
    id = 'mining',
    label = 'Mining',
    order = 41,
    icon = {
        glyph = 'M14 4l6 6M4 20l9-9M12 6c3-3 7-2 8 0-3 0-5 1-7 3M18 12c3 3 2 7 0 8 0-3-1-5-3-7',
        colors = { '#ffcf6b', '#d98a2b', '#8a4c12' },
        glyphColor = '#ffffff',
        tint = '#ffc56b',
    },
}
