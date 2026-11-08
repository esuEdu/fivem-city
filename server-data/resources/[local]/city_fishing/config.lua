lib.locale()

Config = {}

-- Fishing shop (licence, gear, repairs, skill reset), fish market (selling) and the marina (boat rental).
-- Coordinates were placed without the game open: check them in game with /coords (city_base).
Config.Ped = `a_m_m_salton_02`
Config.PedScenario = 'WORLD_HUMAN_STAND_IMPATIENT'
Config.PedDistance = 40.0

Config.Shops = {
    { coords = vec4(-1847.18, -1197.12, 14.31, 150.0), blip = { sprite = 68, color = 3 } },
}

Config.Markets = {
    { coords = vec4(-1838.6, -1200.6, 14.31, 150.0), blip = { sprite = 356, color = 3 } },
}

Config.Marinas = {
    {
        coords = vec4(-734.6, -1311.7, 5.0, 230.0),
        spawn = vec4(-727.87, -1353.1, 0.3, 137.09),
        returnRadius = 60.0,
        blip = { sprite = 410, color = 3 },
    },
}

-- Rod prop and the standing fishing animation
Config.RodProp = `prop_fishing_rod_01`
Config.Anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' }

-- Keys while fishing (control ids): cast / hook / minigame = E (38), stop = X (73)
Config.Keys = { action = 38, stop = 73 }

-- Casting: metres at full power, +1 m at each of these levels
Config.CastRange = 12.0
Config.CastRangeLevels = { 5, 12, 20 }
Config.CastSeconds = 1.6 -- power bar: seconds from empty to full

-- Seconds the player has to press after a bite
Config.HookWindow = 1.0

-- How far around the bobber the water is probed for the shore distance (metres per band, 5 bands)
Config.ShoreBand = 4.0

-- Minigame (logical units; the page scales them). These match what the server expects in sessions.lua.
Config.Minigame = {
    height = 568,
    barBase = 96,
    barPerLevel = 5,
    start = 0.3,       -- progress at the start
    gain = 0.12,       -- per second with the fish inside the bar
    loss = 0.17,       -- per second outside
}

-- The tablet app
Config.App = {
    id = 'fishing',
    label = 'Fishing',
    order = 40,
    icon = {
        glyph = 'M3 12c3-4 7-6 11-6 3 0 5 2 7 6-2 4-4 6-7 6-4 0-8-2-11-6zM3 12l-1.5-3M3 12l-1.5 3M16 10.5h.01',
        colors = { '#6fd3ff', '#2a8fd6', '#145b9c' },
        glyphColor = '#ffffff',
        tint = '#7fd0ff',
    },
}
