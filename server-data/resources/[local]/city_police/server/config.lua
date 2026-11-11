-- Server-only police rules. Low numbers are for testing; tune before launch.
return {
    -- Charges
    maxCharges = 10, -- different crimes in one arrest or fine
    maxCount = 5, -- times one crime is counted
    maxMonths = 120, -- cap on one sentence
    maxFine = 100000, -- cap on one fine (also city_bank's bill cap)
    chargeRange = 10.0, -- an arrest needs the suspect this close; a fine doesn't
    offlineFineDays = 7, -- a fine for someone not in the city is a bank bill due in this many days

    -- Picture of a car on its MDT page, from the model name (the same catalogue city_garages uses)
    vehicleImageUrl = 'https://docs.fivem.net/vehicles/%s.webp',

    -- An arrest is booked only with the suspect cuffed or down, and the officer inside one of these places
    -- (an empty list allows anywhere). Fines are not limited.
    bookingPlaces = {
        { label = 'Mission Row', coords = vec3(441.0, -981.0, 30.7), radius = 60.0 },
        { label = 'Paleto Bay', coords = vec3(-448.4, 6011.8, 31.7), radius = 40.0 },
        { label = 'Bolingbroke', coords = vec3(1699.86, 2605.15, 45.56), radius = 200.0 }, -- city_prison's circle
    },

    -- Searching someone who isn't cuffed, down or hands up asks them first: seconds to answer, seconds between asks
    search = { seconds = 15, cooldown = 10 },

    -- Seconds between two tackles by one officer
    tackleCooldown = 10,

    -- Zip ties are cut with any of these; a head bag falls off by itself after this many minutes
    zipCutters = { 'weapon_knife', 'weapon_switchblade', 'weapon_dagger', 'weapon_machete', 'weapon_bottle' },
    headBagMinutes = 10,

    -- Shots by anyone but police on duty, inside these areas, become a call. A suppressed shot is reported only with
    -- suppressedChance; after a call, the same shooter makes no new one for cooldown seconds.
    shots = {
        cooldown = 20,
        suppressedChance = 0.2,
        suppressors = { at_suppressor_light = true, at_suppressor_heavy = true },
        areas = {
            { label = 'Los Santos', coords = vec3(-300.0, -900.0, 30.0), radius = 2600.0 },
            { label = 'Sandy Shores', coords = vec3(1850.0, 3700.0, 33.0), radius = 600.0 },
            { label = 'Grapeseed', coords = vec3(1700.0, 4800.0, 42.0), radius = 400.0 },
            { label = 'Paleto Bay', coords = vec3(-200.0, 6300.0, 31.0), radius = 600.0 },
        },
    },

    -- BOLOs (be on the lookout) last this many hours unless the officer picks fewer
    boloHours = 48,

    -- Licences: points counted over this many days; at maxPoints the driver licence goes
    pointsDays = 30,
    maxPoints = 20,

    -- Impounds
    impoundFee = 500, -- default fee; the officer may pick 0..maxImpoundFee
    maxImpoundFee = 10000,
    maxHoldHours = 72,

    -- Text limits
    text = { short = 60, line = 160, long = 4000 },

    -- Warrants last this many days unless the officer picks fewer
    warrantDays = 7,

    -- Booking photos (base64 PNG from MugShotBase64)
    maxPhotoBytes = 200000,

    -- Search results returned at most
    searchLimit = 25,

    -- How often (s) unit positions are sent to officers watching the map
    mapSeconds = 3,

    -- Armory (a city_inventory shop; police gear is free, ammo almost)
    armory = {
        { name = 'handcuffs', price = 0 },
        { name = 'zipties', price = 0 },
        { name = 'crowbar', price = 0 },
        { name = 'radio', price = 0 },
        { name = 'police_badge', price = 0 },
        { name = 'empty_evidence_bag', price = 0 },
        { name = 'armour', price = 0 },
        { name = 'weapon_flashlight', price = 0 },
        { name = 'weapon_nightstick', price = 0 },
        { name = 'weapon_stungun', price = 0, metadata = { registered = true, serial = 'POL' } },
        { name = 'weapon_pistol', price = 0, metadata = { registered = true, serial = 'POL' } },
        { name = 'ammo-9', price = 1 },
        { name = 'weapon_pumpshotgun', price = 0, metadata = { registered = true, serial = 'POL' }, grade = 2 },
        { name = 'ammo-shotgun', price = 1, grade = 2 },
        { name = 'weapon_carbinerifle', price = 0, metadata = { registered = true, serial = 'POL' }, grade = 3 },
        { name = 'ammo-rifle', price = 1, grade = 3 },
    },

    locker = { slots = 30, weight = 100000 },
    evidenceLocker = { slots = 200, weight = 2000000 },
    trash = { slots = 50, weight = 1000000 },

    -- Station doors, created in ox_doorlock by name when missing (server/doors.lua); only the police job uses them.
    -- Coords and models are the standard Mission Row interior (ox_doorlock's sql/default.sql). A double door lists
    -- both leaves in `doors`. More doors: add them here, or in game with ox_doorlock's /doorlock (admins).
    doors = {
        { name = 'mrpd armoury', model = 749848321, heading = 270, coords = vec3(453.0843, -982.5795, 30.8193), autolock = 5 },
        { name = 'mrpd locker rooms', model = 1557126584, heading = 90, coords = vec3(450.1041, -985.7384, 30.8393) },
        { name = "mrpd captain's office", model = -1320876379, heading = 180, coords = vec3(446.5728, -980.0106, 30.8393) },
        {
            name = 'mrpd cells/briefing',
            coords = vec3(444.7079, -989.4454, 30.8393),
            doors = {
                { model = 185711165, heading = 0, coords = vec3(446.0079, -989.4454, 30.8393) },
                { model = 185711165, heading = 180, coords = vec3(443.4078, -989.4454, 30.8393) },
            },
        },
        { name = 'mrpd cells main', model = 631614199, heading = 360, coords = vec3(463.9201, -992.6641, 25.0644), lockSound = 'metal-locker', unlockSound = 'metallic-creak' },
        { name = 'mrpd cell 1', model = 631614199, heading = 270, coords = vec3(461.8065, -993.7586, 25.0644), lockSound = 'metal-locker', unlockSound = 'metallic-creak' },
        { name = 'mrpd cell 2', model = 631614199, heading = 90, coords = vec3(461.8065, -998.3083, 25.0644), lockSound = 'metal-locker', unlockSound = 'metallic-creak' },
        { name = 'mrpd cell 3', model = 631614199, heading = 90, coords = vec3(461.8065, -1001.9515, 25.0644), lockSound = 'metal-locker', unlockSound = 'metallic-creak' },
        { name = 'mrpd cells security door', model = -1033001619, heading = 0, coords = vec3(464.1283, -1003.5387, 25.0060), autolock = 5 },
        {
            name = 'mrpd back entrance',
            coords = vec3(468.6698, -1014.4520, 26.5362),
            doors = {
                { model = -2023754432, heading = 0, coords = vec3(467.3716, -1014.4520, 26.5362) },
                { model = -2023754432, heading = 180, coords = vec3(469.9679, -1014.4520, 26.5362) },
            },
        },
        { name = 'mrpd gate', model = -1603817716, heading = 90, coords = vec3(488.8948, -1017.2103, 27.1471), auto = true, maxDistance = 6.0 },
    },
}
