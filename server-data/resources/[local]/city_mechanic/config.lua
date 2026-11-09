Config = {}

Config.Job = 'mechanic'

-- Parts of the job switched on for this version
Config.Features = {
    chargeJob = false, -- off: parts fitted in the tuning bay are free (nothing taken from the mechanic job's account)
}

-- The Mechanic tablet app (city_os): dashboard, 555 calls, team and the tuning bay's service history
Config.App = {
    id = 'mechanic',
    label = 'Mechanic',
    order = 30,
    icon = {
        glyph = 'M15 4a5 5 0 0 0-4.6 6.9L3 18.3 5.7 21l7.4-7.4A5 5 0 0 0 20 9l-3 1-2-2 1-3z',
        colors = { '#ffb070', '#ff7a1a', '#b5480b' },
        glyphColor = '#ffffff',
        tint = '#ffb070',
    },
    service = 'mechanic', -- city_dispatch service whose calls the app shows
    historyLimit = 60, -- services listed in the Services tab
}

-- Staff with this ACE (support < mod < admin) may use the tuning bay without the mechanic job; always free, written
-- to the staff log. nil turns it off.
Config.StaffAce = 'support'
Config.Label = 'Los Santos Customs'

Config.Blip = { coords = vector3(-337.4, -136.0, 39.0), sprite = 446, color = 5, scale = 0.8 }

-- Clock in / out
Config.Duty = vector3(-323.30, -128.79, 39.02)

-- The shop's shared storage (mechanics of any grade)
Config.Stash = { id = 'city_mechanic_stash', coords = vector3(-319.19, -131.90, 37.98), slots = 80, weight = 1000000 }

Config.UseDistance = 2.0

-- The tuning bay: a mechanic on duty drives the car in and presses the key (default E)
Config.Bay = {
    points = {
        vector3(-344.36, -121.92, 38.60),
        vector3(-319.43, -130.65, 38.60),
        vector3(-324.77, -147.93, 38.60),
        vector3(-348.59, -139.1, 38.60),
    },
    thickness = 6.0,
    -- server-side check that the car is really in the bay
    center = vector3(-334.3, -134.9, 38.6),
    radius = 18.0,
}

Config.TuneKey = 'E'

-- Work vehicles: taken out on foot at the garage, put back with the tune key while driving one inside it
Config.Garage = {
    coords = vector3(-370.51, -107.88, 38.35),
    spawn = vector4(-370.51, -107.88, 38.35, 72.56),
    size = vector3(15.0, 5.0, 6.0),
    rotation = 340.0,
    vehicles = {
        { model = 'flatbed', label = 'Flatbed' },
        { model = 'towtruck', label = 'Tow Truck' },
        { model = 'minivan', label = 'Minivan' },
        { model = 'blista', label = 'Blista' },
    },
}

-- Everything bought in the bay is paid from the mechanic job's account (city_bank ChargeJob).
-- The server recomputes every price from this table; the menu only shows it.
Config.Prices = {
    part = 500, -- each body part (spoiler, bumpers, skirts, interior, ...)
    paint = 1000, -- each paint slot (primary, secondary, pearl, wheels, interior, dashboard)
    wheels = 1500, -- rim type or rim
    tyres = 750, -- custom tyres, tyre smoke on/off and its color
    lights = 750, -- xenon on/off, xenon color, neon sides, neon color
    tint = 500,
    plate = 250,
    horn = 250,
    turbo = 10000,
    -- price per level: [1] = level 0 (first upgrade), [2] = level 1, ...; stock (-1) is free
    performance = {
        modEngine = { 10000, 20000, 30000, 40000 },
        modBrakes = { 2500, 5000, 7500 },
        modTransmission = { 5000, 10000, 15000 },
        modSuspension = { 3000, 6000, 9000, 12000, 15000 },
        modArmor = { 5000, 10000, 15000, 20000, 25000 },
    },
    -- full repair in the bay: per point of engine and body damage (each goes 0-1000)
    repairPerPoint = 2,
}

-- Repair kits used next to a car (any player). Mechanics on duty fix it further.
Config.Kits = {
    repairkit = { seconds = 10, engine = 600.0, mechanicEngine = 850.0 },
    advancedrepairkit = { seconds = 15, engine = 850.0, mechanicEngine = 1000.0, mechanicFull = true },
    cleaningkit = { seconds = 8, clean = true },
}

Config.KitDistance = 4.0

-- "Check vehicle" (ox_target on any car, anyone): parts fitted, body, engine and fuel
Config.Inspect = { seconds = 3, distance = 2.5 }
