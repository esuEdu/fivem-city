Config = {}

Config.Job = 'police'

-- The MDT on the iFruit tablet
Config.App = {
    id = 'police_mdt',
    label = 'MDT',
    order = 21,
    icon = {
        glyph = 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6zM12 8.5l1.1 2.2 2.4.3-1.8 1.7.5 2.4-2.2-1.2-2.2 1.2.5-2.4-1.8-1.7 2.4-.3z',
        colors = { '#7aa8ff', '#3f74f0', '#1b3f9e' },
        glyphColor = '#ffffff',
        tint = '#8fb4ff',
    },
}

-- Parts of the job switched on for this version. Off: hidden in the MDT and the field, refused by the server.
Config.Features = {
    map = false, -- the live map tab
    bodycam = false, -- watching a unit's bodycam from the Units tab
    cameras = false, -- the security cameras tab
    evidence = false, -- casings, blood and fingerprints on the ground, the lab and the Evidence tab
    certs = false, -- certifications; off, garage vehicles need none
    anklet = false, -- ankle monitors
    weapons = false, -- the Weapons tab (registered serials; shop purchases are still recorded)
    reports = false, -- the Reports tab
    bolos = false, -- the BOLOs tab
}

-- Lowest job grade for each MDT action (0 Recruit, 1 Officer, 2 Sergeant, 3 Lieutenant, 4 Chief)
Config.Permissions = {
    app = 0,
    dispatch = 0,
    people = 0,
    vehicles = 0,
    flagPlate = 0,
    weapons = 0,
    reports = 0,
    editAnyReport = 2,
    warrants = 0,
    issueWarrant = 2,
    charge = 0,
    impound = 0,
    release = 2,
    licences = 0,
    weaponLicence = 2,
    evidence = 0,
    cameras = 0,
    certs = 0,
    grantCert = 3,
    notices = 3,
    management = 4,
    bolos = 0,
    bodycam = 0,
    map = 0,
    anklet = 0,
}

-- Certifications lieutenants give in the MDT; they unlock vehicles and forensic analysis
Config.Certs = {
    { id = 'air', label = 'Air unit' },
    { id = 'motor', label = 'Motor unit' },
    { id = 'interceptor', label = 'Interceptor' },
    { id = 'tactical', label = 'Tactical (SWAT)' },
    { id = 'forensics', label = 'Forensics' },
}

-- Officer statuses on the Units tab
Config.Statuses = { 'available', 'busy', 'enroute', 'onscene', 'break' }

-- Station places, all opened with ox_target (any of them may be left out). garage/heli: menu = where the officer
-- stands (the vehicle appears at spawn with them inside). Coordinates from qbx_police; check them in game.
Config.Stations = {
    {
        label = 'Mission Row Police Station',
        blip = vec3(434.0, -983.0, 30.7),
        duty = vec3(440.09, -974.92, 30.69),
        armory = vec3(451.51, -979.44, 30.68),
        locker = vec3(453.08, -980.12, 30.89),
        trash = vec3(439.09, -976.75, 30.78),
        lab = vec3(460.97, -989.18, 24.92),
        evidence = vec3(463.5, -989.2, 24.92),
        impound = vec3(436.68, -1007.42, 27.32),
        garage = { menu = vec3(452.0, -996.0, 26.0), spawn = vec4(452.0, -996.0, 26.0, 175.0) },
        heli = { menu = vec3(449.17, -981.33, 43.69), spawn = vec4(449.17, -981.33, 43.69, 87.23) },
    },
    {
        label = 'Paleto Bay Sheriff Office',
        blip = vec3(-448.4, 6011.8, 31.7),
        duty = vec3(-449.81, 6012.91, 31.82),
        impound = vec3(-436.14, 5982.63, 31.34),
        heli = { menu = vec3(-475.43, 5988.35, 31.72), spawn = vec4(-475.43, 5988.35, 31.72, 31.34) },
    },
}

Config.Blip = { sprite = 60, colour = 29, scale = 0.8 }

-- Garage vehicles: lowest grade, and a certification when one is needed
Config.Vehicles = {
    car = {
        { model = 'police', label = 'Cruiser', grade = 0 },
        { model = 'police2', label = 'Buffalo', grade = 0 },
        { model = 'police3', label = 'Interceptor', grade = 1 },
        { model = 'police4', label = 'Unmarked cruiser', grade = 2 },
        { model = 'fbi2', label = 'Unmarked SUV', grade = 3 },
        { model = 'policeb', label = 'Motorcycle', grade = 0, cert = 'motor' },
        { model = 'polgauntlet', label = 'Gauntlet interceptor', grade = 1, cert = 'interceptor' },
        { model = 'riot', label = 'Riot van', grade = 2, cert = 'tactical' },
        { model = 'policet', label = 'Transport van', grade = 0 },
    },
    heli = {
        { model = 'polmav', label = 'Air unit', grade = 1, cert = 'air' },
    },
}
Config.PlatePrefix = 'LSPD'

-- Props from the radial menu; freeze = can't be pushed
Config.Objects = {
    cone = { model = `prop_roadcone02a`, freeze = false },
    barrier = { model = `prop_barrier_work06a`, freeze = true },
    roadsign = { model = `prop_snow_sign_road_06g`, freeze = true },
    tent = { model = `prop_gazebo_03`, freeze = true },
    light = { model = `prop_worklight_03b`, freeze = true },
}
Config.MaxObjects = 10 -- per officer
Config.MaxSpikes = 2 -- per officer
Config.SpikeModel = `p_ld_stinger_s`

-- Ground evidence
Config.Evidence = {
    minutes = 30, -- how long casings, blood and fingerprints stay
    seeDistance = 12.0, -- seen when aiming a flashlight this close
    pickDistance = 1.5,
    casingEvery = 1500, -- ms between two casings from one shooter
}

-- Speed cameras (km/h). A flagged plate passing one creates a call.
Config.Radars = {
    enabled = true,
    kmh = true,
    tolerance = 10, -- over the limit before a ticket
    locations = {
        { coords = vec3(-623.44, -823.08, 25.26), limit = 60 },
        { coords = vec3(-652.44, -854.08, 24.56), limit = 80 },
        { coords = vec3(1623.01, 1068.99, 80.9), limit = 110 },
        { coords = vec3(-2604.9, 2996.34, 27.53), limit = 110 },
        { coords = vec3(2136.65, -591.81, 94.27), limit = 110 },
        { coords = vec3(2117.58, -558.51, 95.68), limit = 110 },
        { coords = vec3(406.9, -969.06, 29.44), limit = 60 },
        { coords = vec3(657.32, -218.82, 44.06), limit = 110 },
        { coords = vec3(2118.29, 6040.03, 50.93), limit = 110 },
        { coords = vec3(-106.3, -1127.55, 30.78), limit = 60 },
        { coords = vec3(-823.37, -1146.98, 8.0), limit = 60 },
    },
}

-- Calls: blip per kind of alert, and how long a call stays
Config.Dispatch = {
    minutes = 20,
    blip = { sprite = 161, colour = 1, scale = 1.2 },
    panicBlip = { sprite = 161, colour = 1, scale = 1.6 },
}

-- Security cameras (the order matters: robbery scripts switch them by index)
Config.Cameras = {
    { label = 'LTD Gasoline - Palomino Ave. - CAM#1', coords = vec3(-705.79, -909.91, 20.9), rot = vec3(-30.0, 0.0, -210.0), rotate = false },
    { label = 'LTD Gasoline - Palomino Ave. - CAM#2', coords = vec3(-710.23, -904.35, 20.78), rot = vec3(-55.0, 0.0, -130.0), rotate = false },
    { label = '24/7 Supermarket - Innocence Blvd. - CAM#1', coords = vec3(25.28, -1348.78, 31.22), rot = vec3(-40.0, 0.0, -25.0), rotate = false },
    { label = '24/7 Supermarket - Innocence Blvd. - CAM#2', coords = vec3(23.8, -1339.77, 30.79), rot = vec3(-20.0, 0.0, -92.0), rotate = false },
    { label = 'LTD Gasoline - Davis Ave. - CAM#1', coords = vec3(-43.08, -1755.2, 31.61), rot = vec3(-30.0, 0.0, -260.0), rotate = false },
    { label = 'LTD Gasoline - Davis Ave. - CAM#2', coords = vec3(-43.97, -1747.98, 31.21), rot = vec3(-55.0, 0.0, -160.0), rotate = false },
    { label = 'LTD Gasoline - Mirror Park Blvd. - CAM#1', coords = vec3(1164.9, -318.34, 71.28), rot = vec3(-30.0, 0.0, -210.0), rotate = false },
    { label = 'LTD Gasoline - Mirror Park Blvd. - CAM#2', coords = vec3(1158.9, -314.25, 71.05), rot = vec3(-55.0, 0.0, -110.0), rotate = false },
    { label = '24/7 Supermarket - Clinton Ave - CAM#1', coords = vec3(373.21, 324.7, 105.24), rot = vec3(-40.0, 0.0, -35.0), rotate = false },
    { label = '24/7 Supermarket - Clinton Ave - CAM#2', coords = vec3(373.73, 333.89, 104.86), rot = vec3(-20.0, 0.0, -105.0), rotate = false },
    { label = 'LTD Gasoline - Banham Canyon Dr - CAM#1', coords = vec3(-1822.22, 798.55, 139.73), rot = vec3(-30.0, 0.0, -180.0), rotate = false },
    { label = 'LTD Gasoline - Banham Canyon Dr - CAM#2', coords = vec3(-1829.57, 798.34, 140.0), rot = vec3(-55.0, 0.0, -91.481), rotate = false },
    { label = '24/7 Supermarket - Palomino Freeway - CAM#1', coords = vec3(2558.76, 381.7, 110.33), rot = vec3(-40.0, 0.0, 60.0), rotate = false },
    { label = '24/7 Supermarket - Palomino Freeway - CAM#2', coords = vec3(2549.13, 380.56, 109.58), rot = vec3(-20.0, 0.0, -10.0), rotate = false },
    { label = '24/7 Supermarket - Señora Freeway - CAM#1', coords = vec3(2679.56, 3279.89, 56.67), rot = vec3(-40.0, 0.0, 40.0), rotate = false },
    { label = '24/7 Supermarket - Señora Freeway - CAM#2', coords = vec3(2670.66, 3282.85, 56.09), rot = vec3(-10.0, 0.0, -40.0), rotate = false },
    { label = '24/7 Supermarket - Niland Ave. - CAM#1', coords = vec3(1961.97, 3739.42, 33.77), rot = vec3(-40.0, 0.0, 20.0), rotate = false },
    { label = '24/7 Supermarket - Niland Ave. - CAM#2', coords = vec3(1955.55, 3746.76, 33.2), rot = vec3(-10.0, 0.0, -70.0), rotate = false },
    { label = '24/7 Supermarket - Route 68 - CAM#1', coords = vec3(547.68, 2672.88, 44.02), rot = vec3(-40.0, 0.0, 160.0), rotate = false },
    { label = '24/7 Supermarket - Route 68 - CAM#2', coords = vec3(550.93, 2662.73, 44.37), rot = vec3(-40.0, 0.0, 60.0), rotate = false },
    { label = '24/7 Supermarket - Señora Freeway, Mount Chillad - CAM#1', coords = vec3(1726.85, 6413.76, 37.64), rot = vec3(-40.0, 0.0, -80.0), rotate = false },
    { label = '24/7 Supermarket - Señora Freeway, Mount Chillad - CAM#2', coords = vec3(1731.16, 6423.27, 37.28), rot = vec3(-40.0, 0.0, 210.0), rotate = false },
    { label = 'LTD Gasoline - Grapeseed Main St. - CAM#1', coords = vec3(1700.33, 4919.91, 44.04), rot = vec3(-30.0, 0.0, 0.0), rotate = false },
    { label = 'LTD Gasoline - Grapeseed Main St. - CAM#2', coords = vec3(1708.34, 4920.88, 43.68), rot = vec3(-55.0, 0.0, 100.0), rotate = false },
    { label = '24/7 Supermarket - Barbareno Rd. - CAM#1', coords = vec3(-3240.69, 1000.9, 14.51), rot = vec3(-40.0, 0.0, 65.0), rotate = false },
    { label = '24/7 Supermarket - Barbareno Rd. - CAM#2', coords = vec3(-3249.74, 999.95, 14.13), rot = vec3(-10.0, 0.0, -5.0), rotate = false },
    { label = '24/7 Supermarket - Ineseno Rd. - CAM#1', coords = vec3(-3037.53, 584.58, 10.15), rot = vec3(-40.0, 0.0, 65.0), rotate = false },
    { label = '24/7 Supermarket - Ineseno Rd. - CAM#2', coords = vec3(-3047.28, 582.21, 9.93), rot = vec3(-30.0, 0.0, -5.0), rotate = false },
    { label = 'Rob\'s Liquors - San Andreas Ave. - CAM#1', coords = vec3(-1224.874, -911.094, 14.401), rot = vec3(-35.0, 0.0, -6.778894), rotate = false },
    { label = 'Rob\'s Liquors - Prosperity St. - CAM#1', coords = vec3(-1482.9, -380.463, 42.363), rot = vec3(-35.0, 0.0, 79.53281), rotate = false },
    { label = 'Rob\'s Liquors - El Rancho Blvd. - CAM#1', coords = vec3(1133.024, -978.712, 48.515), rot = vec3(-35.0, 0.0, -137.302), rotate = false },
    { label = 'Rob\'s Liquors - Route 68 - CAM#1', coords = vec3(1169.855, 2711.493, 40.432), rot = vec3(-35.0, 0.0, 127.17), rotate = false },
    { label = 'Rob\'s Liquors - Autopista de Great Ocean - CAM#1', coords = vec3(-2966.1, 386.92, 17.39), rot = vec3(-35.0, 0.0, 20.0), rotate = false },
    { label = 'Fleeca Bank - Meteor St. - CAM#1', coords = vec3(309.341, -281.439, 55.88), rot = vec3(-35.0, 0.0, -146.1595), rotate = false },
    { label = 'Fleeca Bank - Vespucci Blvd. - CAM#1', coords = vec3(144.871, -1043.044, 31.017), rot = vec3(-35.0, 0.0, -143.9796), rotate = false },
    { label = 'Fleeca Bank - Hawick Ave. - CAM#1 ', coords = vec3(-355.7643, -52.506, 50.746), rot = vec3(-35.0, 0.0, -143.8711), rotate = false },
    { label = 'Fleeca Bank - Del Perro Blvd. - CAM#1', coords = vec3(-1214.226, -335.86, 39.515), rot = vec3(-35.0, 0.0, -97.862), rotate = false },
    { label = 'Fleeca Bank - Great Ocean Hwy. - CAM#1', coords = vec3(-2958.885, 478.983, 17.406), rot = vec3(-35.0, 0.0, -34.69595), rotate = false },
    { label = 'Fleeca Bank - Route 68 - CAM#1', coords = vec3(1178.8, 2710.78, 39.66), rot = vec3(-35.0, 0.0, 50.0), rotate = false },
    { label = 'Pacific Bank - CAM#1', coords = vec3(265.61, 212.97, 111.28), rot = vec3(-25.0, 0.0, 28.05), rotate = false },
    { label = 'Pacific Bank - CAM#2', coords = vec3(232.86, 221.46, 107.83), rot = vec3(-25.0, 0.0, -140.91), rotate = false },
    { label = 'Pacific Bank - CAM#3', coords = vec3(232.21, 233.69, 99.42), rot = vec3(-45.05, 10.0, 120.0), rotate = false },
    { label = 'Paleto Bank - CAM#1', coords = vec3(-102.939, 6467.668, 33.424), rot = vec3(-35.0, 0.0, 24.66), rotate = false },
    { label = 'Vangelico Jewelery - CAM#1', coords = vec3(-627.54, -239.74, 40.33), rot = vec3(-35.0, 0.0, 5.78), rotate = true },
    { label = 'Vangelico Jewelery - CAM#2', coords = vec3(-627.51, -229.51, 40.24), rot = vec3(-35.0, 0.0, -95.78), rotate = true },
    { label = 'Vangelico Jewelery - CAM#3', coords = vec3(-620.3, -224.31, 40.23), rot = vec3(-35.0, 0.0, 165.78), rotate = true },
    { label = 'Vangelico Jewelery - CAM#4', coords = vec3(-622.57, -236.3, 40.31), rot = vec3(-35.0, 0.0, 5.78), rotate = true },
}

Config.Ranges = {
    place = 2.5, -- station places
    cuff = 2.0, -- cuffing and soft cuffing
    player = 3.0, -- escorting, searching, the other actions on a player
    vehicle = 6.0, -- putting someone in a car, impounding
    tackle = 2.5, -- the suspect in front of a sprinting officer
}

-- Keys (players can change them in the game's key bindings)
Config.Keys = {
    tackle = 'G',
    radar = 'F7', -- turn the patrol car radar on or off
    radarLock = 'F6', -- freeze the readings
    megaphone = 'Y', -- hold in a police car
}

-- Tackling: both fall; the suspect stays down longer
Config.Tackle = { suspectMs = 3500, officerMs = 1200 }

-- Patrol car radar (km/h): how far it looks ahead and behind, and how often it reads
Config.PatrolRadar = { range = 60.0, everyMs = 250 }

-- Megaphone: the voice range while the key is held in a police car
Config.Megaphone = { range = 40.0 }

-- Zip ties and the head bag: anyone may use them on a player with their hands up, cuffed or down
Config.Restraints = {
    zipTies = 'zipties',
    headBag = 'head_bag',
    headBagProp = `prop_money_bag_01`,
}

-- Forcing a locked car open: police on duty with the crowbar item
Config.Crowbar = { item = 'crowbar', seconds = 8 }

-- Things a cuffed player can't do (controls)
Config.CuffedControls = { 21, 22, 23, 24, 25, 26, 36, 37, 44, 45, 47, 58, 59, 71, 72, 73, 75, 140, 141, 142, 143, 199, 257, 263, 264, 288, 289, 170, 167 }
