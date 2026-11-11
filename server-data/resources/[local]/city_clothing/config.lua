Config = {}

-- Who serves the shop: a local ped at each store's coords, with ox_target on it
Config.Clerks = {
    clothing = { model = `a_f_y_hipster_02`, label = 'Browse clothes', icon = 'fas fa-shirt' },
    barber = { model = `s_f_m_fembarber`, label = 'Get a haircut', icon = 'fas fa-scissors' },
    tattoo = { model = `u_m_y_tattoo_01`, label = 'Get a tattoo', icon = 'fas fa-pen-nib' },
}

Config.Blips = {
    clothing = { sprite = 73, color = 47, scale = 0.7, label = 'Clothing Store' },
    barber = { sprite = 71, color = 0, scale = 0.7, label = 'Barber' },
    tattoo = { sprite = 75, color = 1, scale = 0.7, label = 'Tattoo Parlor' },
}

-- How far the clerk ped is spawned, and how close the player must stay to buy (also checked on the server)
Config.SpawnDistance = 40.0
Config.UseDistance = 6.0

-- The stores (illenium-appearance's old ones): where the clerk stands
Config.Stores = {
    { type = 'clothing', coords = vector4(1693.2, 4828.11, 42.07, 188.66) },
    { type = 'clothing', coords = vector4(-705.5, -149.22, 37.42, 122.0) },
    { type = 'clothing', coords = vector4(-1192.61, -768.4, 17.32, 216.6) },
    { type = 'clothing', coords = vector4(425.91, -801.03, 29.49, 177.79) },
    { type = 'clothing', coords = vector4(-168.73, -301.41, 39.73, 238.67) },
    { type = 'clothing', coords = vector4(75.39, -1398.28, 29.38, 6.73) },
    { type = 'clothing', coords = vector4(-827.39, -1075.93, 11.33, 294.31) },
    { type = 'clothing', coords = vector4(-1445.86, -240.78, 49.82, 36.17) },
    { type = 'clothing', coords = vector4(9.22, 6515.74, 31.88, 131.27) },
    { type = 'clothing', coords = vector4(615.35, 2762.72, 42.09, 170.51) },
    { type = 'clothing', coords = vector4(1191.61, 2710.91, 38.22, 269.96) },
    { type = 'clothing', coords = vector4(-3171.32, 1043.56, 20.86, 334.3) },
    { type = 'clothing', coords = vector4(-1105.52, 2707.79, 19.11, 317.19) },
    { type = 'clothing', coords = vector4(-1119.24, -1440.6, 5.23, 300.5) },
    { type = 'clothing', coords = vector4(124.82, -224.36, 54.56, 335.41) },
    { type = 'barber', coords = vector4(-814.22, -183.7, 37.57, 116.91) },
    { type = 'barber', coords = vector4(136.78, -1708.4, 29.29, 144.19) },
    { type = 'barber', coords = vector4(-1282.57, -1116.84, 6.99, 89.25) },
    { type = 'barber', coords = vector4(1931.41, 3729.73, 32.84, 212.08) },
    { type = 'barber', coords = vector4(1212.8, -472.9, 65.2, 60.94) },
    { type = 'barber', coords = vector4(-32.9, -152.3, 56.1, 335.22) },
    { type = 'barber', coords = vector4(-278.1, 6228.5, 30.7, 49.32) },
    { type = 'tattoo', coords = vector4(1322.6, -1651.9, 51.2, 42.47) },
    { type = 'tattoo', coords = vector4(-1154.01, -1425.31, 4.95, 23.21) },
    { type = 'tattoo', coords = vector4(322.62, 180.34, 103.59, 156.2) },
    { type = 'tattoo', coords = vector4(-3169.52, 1074.86, 20.83, 253.29) },
    { type = 'tattoo', coords = vector4(1864.1, 3747.91, 33.03, 17.23) },
    { type = 'tattoo', coords = vector4(-294.24, 6200.12, 31.49, 195.72) },
}

-- What each kind of store sells, in tab order. kind: component / prop / hair / overlay (game ids in slot), or tattoo
-- (a zone of illenium-appearance's tattoo list; any number of them, each one priced on its own).
-- shot = camera framing; sex = only shown to that sex. Prices are in server/config.lua.
Config.Categories = {
    clothing = {
        { id = 'tops', label = 'Tops', kind = 'component', slot = 11, shot = 'torso' },
        { id = 'undershirts', label = 'Undershirts', kind = 'component', slot = 8, shot = 'torso' },
        { id = 'arms', label = 'Arms & gloves', kind = 'component', slot = 3, shot = 'torso' },
        { id = 'pants', label = 'Pants', kind = 'component', slot = 4, shot = 'legs' },
        { id = 'shoes', label = 'Shoes', kind = 'component', slot = 6, shot = 'feet' },
        { id = 'neck', label = 'Neck & ties', kind = 'component', slot = 7, shot = 'torso' },
        { id = 'bags', label = 'Bags', kind = 'component', slot = 5, shot = 'back' },
        { id = 'masks', label = 'Masks', kind = 'component', slot = 1, shot = 'face' },
        { id = 'hats', label = 'Hats', kind = 'prop', slot = 0, shot = 'face' },
        { id = 'glasses', label = 'Glasses', kind = 'prop', slot = 1, shot = 'face' },
        { id = 'earrings', label = 'Earrings', kind = 'prop', slot = 2, shot = 'face' },
        { id = 'watches', label = 'Watches', kind = 'prop', slot = 6, shot = 'wrist' },
        { id = 'bracelets', label = 'Bracelets', kind = 'prop', slot = 7, shot = 'wrist' },
    },
    barber = {
        { id = 'hair', label = 'Hair', kind = 'hair', slot = 2, shot = 'face' },
        { id = 'beard', label = 'Beard', kind = 'overlay', slot = 1, shot = 'face', sex = 'm', colors = 'hair' },
        { id = 'eyebrows', label = 'Eyebrows', kind = 'overlay', slot = 2, shot = 'face', colors = 'hair' },
        { id = 'chestHair', label = 'Chest hair', kind = 'overlay', slot = 10, shot = 'torso', sex = 'm', colors = 'hair' },
        { id = 'makeup', label = 'Makeup', kind = 'overlay', slot = 4, shot = 'face', colors = 'makeup' },
        { id = 'blush', label = 'Blush', kind = 'overlay', slot = 5, shot = 'face', colors = 'makeup' },
        { id = 'lipstick', label = 'Lipstick', kind = 'overlay', slot = 8, shot = 'face', colors = 'makeup' },
        { id = 'hairDetails', label = 'Hair details', kind = 'tattoo', zone = 'ZONE_HAIR', shot = 'face' },
    },
    tattoo = {
        { id = 'torso', label = 'Torso & back', kind = 'tattoo', zone = 'ZONE_TORSO', shot = 'torso' },
        { id = 'head', label = 'Head & neck', kind = 'tattoo', zone = 'ZONE_HEAD', shot = 'face' },
        { id = 'leftArm', label = 'Left arm', kind = 'tattoo', zone = 'ZONE_LEFT_ARM', shot = 'leftArm' },
        { id = 'rightArm', label = 'Right arm', kind = 'tattoo', zone = 'ZONE_RIGHT_ARM', shot = 'rightArm' },
        { id = 'leftLeg', label = 'Left leg', kind = 'tattoo', zone = 'ZONE_LEFT_LEG', shot = 'leftLeg' },
        { id = 'rightLeg', label = 'Right leg', kind = 'tattoo', zone = 'ZONE_RIGHT_LEG', shot = 'rightLeg' },
    },
}

-- Most tattoos one body zone can hold
Config.MaxTattoosPerZone = 25

-- Shop camera framings: bone to look at, distance in front of the ped, height offset, field of view
Config.Shots = {
    face = { bone = 31086, distance = 0.85, height = 0.0, fov = 30.0 },
    torso = { bone = 24818, distance = 1.5, height = 0.05, fov = 36.0 },
    back = { bone = 24818, distance = 1.5, height = 0.05, fov = 36.0, behind = true },
    legs = { bone = 11816, distance = 1.6, height = -0.35, fov = 38.0 },
    feet = { bone = 11816, distance = 1.3, height = -0.85, fov = 34.0 },
    wrist = { bone = 18905, distance = 0.8, height = 0.0, fov = 30.0, side = true },
    body = { bone = 11816, distance = 2.8, height = 0.0, fov = 40.0 },
    -- Tattoo zones: angle turns the camera around the ped (degrees, + = the ped's left)
    leftArm = { bone = 61163, distance = 1.1, height = 0.0, fov = 36.0, angle = 90.0 },
    rightArm = { bone = 28252, distance = 1.1, height = 0.0, fov = 36.0, angle = -90.0 },
    leftLeg = { bone = 58271, distance = 1.4, height = -0.2, fov = 38.0, angle = 35.0 },
    rightLeg = { bone = 51826, distance = 1.4, height = -0.2, fov = 38.0, angle = -35.0 },
}

-- Saved looks per character (illenium-appearance's player_outfits table, so house wardrobes see them too)
Config.MaxOutfits = 20

-- The photo tool (Staff app): pictures of every piece, saved in images/ and shown on the shop cards.
-- Only staff with Config.PhotoAce. Each sex gets the base outfit below, then one piece at a time.
Config.PhotoAce = 'admin'
Config.Photos = {
    -- Under Mission Row (city_character's lineup room), alone in a routing bucket while it runs
    spot = vector4(402.87, -996.55, -99.0, 180.0),
    -- Plain backdrop drawn behind the ped, in RGB
    backdrop = { 26, 28, 34 },
    -- How long a piece gets to stream in before its picture is taken
    settleMs = 350,
    -- Capture size: shop cards show the middle square of it
    width = 480,
    height = 270,
    -- Underwear: what the ped wears around the piece being photographed. Arms (3) stay 9 in every picture
    base = {
        m = { [1] = 0, [3] = 9, [4] = 61, [5] = 0, [6] = 34, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
        f = { [1] = 0, [3] = 9, [4] = 17, [5] = 0, [6] = 35, [7] = 0, [8] = 14, [9] = 0, [10] = 0, [11] = 15 },
    },
    -- Undershirt worn for the pictures of the Arms & gloves tab
    armsUndershirt = 15,
    -- Hair color for hair, beard, eyebrows and chest hair pictures; makeup color for makeup ones
    hairColor = 0,
    makeupColor = 1,
}
