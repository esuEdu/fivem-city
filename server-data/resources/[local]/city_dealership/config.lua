Config = {}

Config.Label = 'Premium Deluxe Motorsport'

Config.Blip = { coords = vec3(-45.67, -1098.34, 26.42), sprite = 326, color = 3, scale = 0.7 }

-- Computers players use to open the catalogue (ox_target box zones on the desks)
Config.Computers = {
    { coords = vec3(-29.53, -1103.67, 26.42), size = vec3(1.4, 1.4, 2.4), rotation = 0.0 },
}

Config.UseDistance = 2.5 -- how close to a computer the player must be

-- Garage (city_garages) where bought cars are delivered; it puts them out on a free spot of the PDM lot
Config.Garage = 'pdm'

-- qbx_core categories sold here, in the order the catalogue lists them. Anything else (emergency, military, service,
-- commercial, industrial, trains, boats, aircraft, openwheel, utility) is not sold.
Config.Categories = {
    { id = 'compacts', label = 'Compacts' },
    { id = 'sedans', label = 'Sedans' },
    { id = 'coupes', label = 'Coupes' },
    { id = 'suvs', label = 'SUVs' },
    { id = 'offroad', label = 'Off-road' },
    { id = 'muscle', label = 'Muscle' },
    { id = 'sportsclassics', label = 'Classics' },
    { id = 'sports', label = 'Sports' },
    { id = 'super', label = 'Super' },
    { id = 'motorcycles', label = 'Motorcycles' },
    { id = 'vans', label = 'Vans' },
    { id = 'cycles', label = 'Bicycles' },
}

-- Models never sold even when their category is
Config.Blocklist = {
    police = true,
    police2 = true,
    police3 = true,
    police4 = true,
    gemera = true, -- add-on car, spawn only
}

-- Picture of each model: the catalogue picture, or an override per model (add-on cars have none at the default
-- address; the page shows a placeholder when it fails to load)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'
Config.Images = {
    -- mymodcar = 'https://example.com/mymodcar.webp',
}

Config.TestDrive = {
    seconds = 120,
    -- the test car appears on the first free spot of the lot and the player is put inside
    spawns = {
        vec4(-61.35, -1110.31, 25.86, 71.01),
        vec4(-59.61, -1104.74, 25.85, 70.13),
        vec4(-52.96, -1113.49, 25.87, 71.53),
        vec4(-52.34, -1107.93, 25.87, 71.63),
        vec4(-44.27, -1116.36, 25.87, 71.7),
        vec4(-41.75, -1111.49, 25.87, 71.5),
    },
    clearRadius = 3.0, -- a spot is free when no vehicle is this close
    returnTo = vec4(-32.77, -1095.75, 26.42, 70.0), -- where the player is put back when it ends
    maxDistance = 1500.0, -- the test ends early when the car goes this far from the dealership
}

-- Parts of the dealership switched on for this version. Off: hidden on the computer, refused by the server.
Config.Features = {
    finance = false, -- financed purchases (down payment + installment bills); off, cars are bought in full only
}

Config.Finance = {
    minDownPct = 20, -- smallest down payment, % of the price
    installments = { 5, 10, 15 }, -- choices offered, one installment every `everyHours`
    interestPct = 10, -- added once to the financed part
    everyHours = 24, -- real hours between installments
    dueHours = 24, -- each installment bill is due this long after it is issued
    repoAfter = 2, -- the car is taken back once this many installment bills are overdue
    maxActive = 2, -- financed cars per character at once
}
