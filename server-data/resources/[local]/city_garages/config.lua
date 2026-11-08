Config = {}

-- Ped that stands at each garage; players open the garage with ox_target on it
Config.Ped = `s_m_y_valet_01`
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'
Config.PedDistance = 60.0 -- the ped is spawned only while the player is this close

Config.UseDistance = 4.0 -- how close to the ped (or garage point) the player must be to open it
Config.ParkRadius = 25.0 -- a car this close to a garage's ped or spawn points can be parked there
Config.SpawnClearRadius = 3.0 -- a spawn point is free when no vehicle is this close

-- Picture shown when a car is clicked in the list: the model's catalogue picture, or an override per model
-- (addon cars have no picture at the default address; the page shows a placeholder when it fails to load)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'
Config.Images = {
    -- mymodcar = 'https://example.com/mymodcar.webp',
}

-- qbx_core vehicle `type` -> garage kind; anything not listed is a car
Config.TypeKinds = {
    heli = 'air',
    plane = 'air',
    boat = 'sea',
    submarine = 'sea',
}

-- GTA vehicle class -> garage kind, for the car in front of the player (anything not listed is a car)
Config.ClassKinds = {
    [14] = 'sea',
    [15] = 'air',
    [16] = 'air',
}

-- Default blip per kind; a garage can override it with `blip = { ... }` or hide it with `blip = false`
Config.Blips = {
    car = { name = 'Public Parking', sprite = 357, color = 3 },
    air = { name = 'Hangar', sprite = 360, color = 3 },
    sea = { name = 'Boathouse', sprite = 356, color = 3 },
    depot = { name = 'Impound Lot', sprite = 68, color = 3 },
}

-- Every garage holds all of a player's cars of its kind: park in one, take out in any other.
-- depot = true: an impound lot, where cars left out on the street (not in the world any more) are taken back for a fee.
-- groups = job/gang (qbx_core primary group filter) that may use it.
-- coords = where the ped stands (vector4), spawns = where taken-out cars appear (the first free one is used).
Config.Garages = {
    motelgarage = { label = 'Motel Parking', kind = 'car', coords = vec4(275.58, -344.74, 45.17, 70.0), spawns = { vec4(271.26, -342.32, 44.7, 159.97) } },
    sapcounsel = { label = 'San Andreas Parking', kind = 'car', coords = vec4(-330.67, -781.12, 33.96, 40.46), spawns = { vec4(-337.11, -775.34, 33.56, 132.09) } },
    spanishave = { label = 'Spanish Ave Parking', kind = 'car', coords = vec4(-1160.46, -741.04, 19.95, 41.26), spawns = { vec4(-1165.38, -747.65, 18.94, 40.45) } },
    caears24 = { label = 'Caears 24 Parking', kind = 'car', coords = vec4(68.08, 13.15, 69.21, 160.44), spawns = { vec4(72.61, 11.72, 68.47, 157.59) } },
    littleseoul = { label = 'Little Seoul Parking', kind = 'car', coords = vec4(-463.51, -808.2, 30.54, 0.0), spawns = { vec4(-472.24, -813.61, 30.3, 179.88) } },
    lagunapi = { label = 'Laguna Parking', kind = 'car', coords = vec4(363.85, 297.97, 103.5, 341.39), spawns = { vec4(367.41, 297.02, 103.2, 341.08) } },
    airportp = { label = 'Airport Parking', kind = 'car', coords = vec4(-796.07, -2023.26, 9.17, 55.18), spawns = { vec4(-793.35, -2020.62, 8.51, 58.42) } },
    beachp = { label = 'Beach Parking', kind = 'car', coords = vec4(-1184.21, -1509.65, 4.65, 303.72), spawns = { vec4(-1184.4, -1501.88, 4.39, 214.7) } },
    themotorhotel = { label = 'The Motor Hotel Parking', kind = 'car', coords = vec4(1137.77, 2663.54, 37.9, 0.0), spawns = { vec4(1137.56, 2674.19, 38.17, 359.95) } },
    liqourparking = { label = 'Liquor Parking', kind = 'car', coords = vec4(960.68, 3609.32, 32.98, 268.97), spawns = { vec4(960.48, 3605.71, 32.98, 87.09) } },
    shoreparking = { label = 'Shore Parking', kind = 'car', coords = vec4(1726.9, 3710.38, 34.26, 22.54), spawns = { vec4(1728.65, 3714.85, 34.18, 21.26) } },
    haanparking = { label = 'Bell Farms Parking', kind = 'car', coords = vec4(78.34, 6418.74, 31.28, 0.0), spawns = { vec4(70.71, 6425.16, 30.92, 68.5) } },
    dumbogarage = { label = 'Dumbo Private Parking', kind = 'car', coords = vec4(157.26, -3240.0, 7.0, 0.0), spawns = { vec4(165.32, -3236.1, 5.93, 268.5) } },
    -- Premium Deluxe Motorsport lot: cars bought at city_dealership are delivered here
    pdm = {
        label = 'PDM Parking', kind = 'car', coords = vec4(-35.6, -1112.4, 26.44, 70.0),
        blip = { name = 'PDM Parking', sprite = 357, color = 3 },
        spawns = {
            vec4(-61.35, -1110.31, 25.86, 71.01), vec4(-59.61, -1104.74, 25.85, 70.13), vec4(-52.96, -1113.49, 25.87, 71.53),
            vec4(-52.34, -1107.93, 25.87, 71.63), vec4(-44.27, -1116.36, 25.87, 71.7), vec4(-41.75, -1111.49, 25.87, 71.5),
        },
    },
    pillboxgarage = { label = 'Pillbox Garage Parking', kind = 'car', coords = vec4(218.66, -804.08, 30.75, 65.69), spawns = { vec4(229.33, -805.01, 30.54, 156.79) } },

    intairport = { label = 'Airport Hangar', kind = 'air', coords = vec4(-1025.34, -3017.0, 13.95, 331.99), spawns = { vec4(-979.2, -2995.51, 13.95, 52.19) } },
    higginsheli = { label = 'Higgins Helitours', kind = 'air', coords = vec4(-722.12, -1472.74, 5.0, 140.0), spawns = { vec4(-724.83, -1443.89, 5.0, 140.0) } },
    airsshores = { label = 'Sandy Shores Hangar', kind = 'air', coords = vec4(1757.74, 3296.13, 41.15, 142.6), spawns = { vec4(1740.88, 3278.99, 41.09, 189.46) } },

    lsymc = { label = 'LSYMC Boathouse', kind = 'sea', coords = vec4(-794.64, -1510.89, 1.6, 201.55), spawns = { vec4(-793.58, -1501.4, 0.12, 111.5) } },
    paleto = { label = 'Paleto Boathouse', kind = 'sea', coords = vec4(-277.4, 6637.01, 7.5, 40.51), spawns = { vec4(-289.2, 6637.96, 1.01, 45.5) } },
    millars = { label = 'Millars Boathouse', kind = 'sea', coords = vec4(1299.02, 4216.42, 33.91, 166.8), spawns = { vec4(1296.78, 4203.76, 30.12, 169.03) } },

    ballas = { label = 'Ballas', kind = 'car', groups = 'ballas', blip = false, coords = vec4(98.5, -1954.49, 20.84, 0.0), spawns = { vec4(98.5, -1954.49, 20.75, 335.73) } },
    families = { label = 'La Familia', kind = 'car', groups = 'families', blip = false, coords = vec4(-811.65, 187.49, 72.48, 0.0), spawns = { vec4(-818.43, 184.97, 72.28, 107.85) } },
    lostmc = { label = 'Lost MC', kind = 'car', groups = 'lostmc', blip = false, coords = vec4(957.25, -129.63, 74.39, 0.0), spawns = { vec4(957.25, -129.63, 74.39, 199.21) } },
    cartel = { label = 'Cartel', kind = 'car', groups = 'cartel', blip = false, coords = vec4(1407.18, 1118.04, 114.84, 0.0), spawns = { vec4(1407.18, 1118.04, 114.84, 88.34) } },

    impoundlot = { label = 'Impound Lot', kind = 'car', depot = true, coords = vec4(400.45, -1630.87, 29.29, 228.88), spawns = { vec4(407.2, -1645.58, 29.31, 228.28) } },
    airdepot = { label = 'Air Depot', kind = 'air', depot = true, blip = { name = 'Air Depot', sprite = 359, color = 3 }, coords = vec4(-1244.35, -3391.39, 13.94, 59.26), spawns = { vec4(-1269.03, -3376.7, 13.94, 330.32) } },
    seadepot = { label = 'LSYMC Depot', kind = 'sea', depot = true, blip = { name = 'LSYMC Depot', sprite = 356, color = 3 }, coords = vec4(-772.71, -1431.11, 1.6, 48.03), spawns = { vec4(-729.77, -1355.49, 1.19, 142.5) } },
}
