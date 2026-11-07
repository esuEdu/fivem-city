Config = {}

-- Bolingbroke Penitentiary. The spawns, desk, computer, terminals and circle come from xt-prison; everything else
-- (infirmary, job board and spots, fountains, tray, contraband, gate doors) was placed without the game open: check.

-- Leaving this circle while serving is an escape
Config.Prison = {
    label = 'Bolingbroke Penitentiary',
    center = vec3(1699.86, 2605.15, 45.56),
    radius = 200.0,
    blip = { coords = vec3(1845.9, 2585.9, 45.67), sprite = 285, color = 3, scale = 0.75 },
}

-- Where a new inmate appears (one at random) and where a downed inmate wakes up
Config.Spawns = {
    vec4(1770.72, 2479.98, 45.74, 31.66),
    vec4(1761.07, 2474.92, 49.69, 33.12),
    vec4(1745.03, 2479.21, 45.74, 323.07),
    vec4(1768.13, 2481.68, 45.74, 33.28),
}
Config.Infirmary = vec4(1745.9, 2469.2, 45.85, 180.0) -- check

-- Where a released inmate is let out
Config.Freedom = vec4(1842.58, 2573.43, 45.89, 357.77)

-- The release desk (get out once the time is served, or collect belongings later) and the prison computer (police)
Config.Desk = { coords = vec3(1836.5, 2592.05, 46.35), size = vec3(0.9, 7.8, 1.45), rotation = 0.5 }
Config.Computer = { coords = vec3(1837.45, 2592.95, 45.85), radius = 0.5 }

-- Police job and the lowest grade for each prison computer action
Config.PoliceJob = 'police'
Config.ComputerGrades = {
    view = 0,
    setTime = 2,
    release = 2,
    clearEscape = 3,
}

-- Prison clothes, put on when entering; the player's own outfit comes back on release (illenium-appearance)
Config.Uniform = {
    male = { [1] = { 0, 0 }, [3] = { 0, 0 }, [4] = { 5, 7 }, [6] = { 42, 2 }, [7] = { 0, 0 }, [8] = { 15, 0 }, [11] = { 0, 0 } },
    female = { [1] = { 0, 0 }, [3] = { 14, 0 }, [4] = { 3, 15 }, [6] = { 4, 0 }, [7] = { 0, 0 }, [8] = { 14, 0 }, [11] = { 0, 0 } },
}

-- Jobs: the board gives one spot at a time; finishing it takes months off (server/config.lua)
Config.JobBoard = vec3(1772.9, 2494.7, 45.74) -- check
Config.Jobs = {
    cleaning = {
        icon = 'fas fa-broom',
        anim = { scenario = 'WORLD_HUMAN_JANITOR' },
        spots = {
            vec3(1749.0, 2519.6, 45.56),
            vec3(1717.1, 2560.9, 45.56),
            vec3(1690.6, 2531.1, 45.56),
            vec3(1736.7, 2490.6, 45.56),
            vec3(1764.9, 2505.3, 45.56),
        },
    },
    kitchen = {
        icon = 'fas fa-utensils',
        anim = { scenario = 'PROP_HUMAN_BBQ' },
        spots = {
            vec3(1780.8, 2560.1, 45.67),
            vec3(1776.9, 2564.8, 45.67),
            vec3(1783.9, 2557.6, 45.67),
        },
    },
    electrical = {
        icon = 'fas fa-bolt',
        anim = { dict = 'anim@gangops@facility@servers@', clip = 'hotwire' },
        skillCheck = { 'easy', 'medium', 'easy' },
        spots = {
            vec3(1761.6, 2540.6, 45.56),
            vec3(1718.5, 2527.6, 45.56),
            vec3(1700.3, 2474.8, 45.56),
            vec3(1663.7, 2501.6, 45.56),
        },
    },
}

-- Free food and water (no items: hunger and thirst go up straight away)
Config.Fountains = {
    vec3(1767.4, 2502.2, 45.56),
    vec3(1712.0, 2541.0, 45.56),
}
Config.Tray = vec3(1778.31, 2560.56, 45.62)

-- Hidden spots where parts for contraband turn up
Config.Contraband = {
    vec3(1773.7, 2492.0, 45.74),
    vec3(1648.8, 2541.5, 45.56),
    vec3(1709.0, 2569.5, 45.56),
    vec3(1752.4, 2476.9, 45.74),
    vec3(1691.2, 2470.3, 45.56),
}

-- Gates: hacking a terminal opens its gate for a while. Each gate is an ox_doorlock door, created by name if missing.
Config.Gates = {
    { name = 'city_prison_gate_1', model = `prop_gate_prison_01`, coords = vec3(1844.99, 2604.81, 44.64), heading = 90.0 },
    { name = 'city_prison_gate_2', model = `prop_gate_prison_01`, coords = vec3(1818.54, 2604.81, 44.61), heading = 90.0 },
}
Config.Terminals = {
    { coords = vec3(1846.05, 2604.7, 45.65), gate = 1 },
    { coords = vec3(1843.95, 2602.7, 45.65), gate = 1 },
    { coords = vec3(1819.55, 2604.7, 45.6), gate = 2 },
    { coords = vec3(1817.4, 2602.7, 45.65), gate = 2 },
}
Config.HackSkillCheck = { 'easy', 'medium', 'medium' }
