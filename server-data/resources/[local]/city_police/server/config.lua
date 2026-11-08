-- Server-only police rules. Low numbers are for testing; tune before launch.
return {
    -- Charges
    maxCharges = 10, -- different crimes in one arrest or fine
    maxCount = 5, -- times one crime is counted
    maxMonths = 120, -- cap on one sentence
    maxFine = 100000, -- cap on one fine (also city_bank's bill cap)
    chargeRange = 10.0, -- an arrest needs the suspect this close; a fine doesn't

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

    -- Seconds between two radar tickets for one player
    radarCooldown = 120,

    -- Search results returned at most
    searchLimit = 25,

    -- How often (s) unit positions are sent to officers watching the map
    mapSeconds = 3,

    -- Armory (a city_inventory shop; police gear is free, ammo almost)
    armory = {
        { name = 'handcuffs', price = 0 },
        { name = 'radio', price = 0 },
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
}
