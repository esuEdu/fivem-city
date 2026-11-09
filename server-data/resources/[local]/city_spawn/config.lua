Config = {}

-- Shown left to right. `last = true` is where the character logged out (no coords: read on the server).
-- icon: garage, police, hospital, north, pin. color: the icon tile behind it.
Config.Spots = {
    { id = 'legion', label = 'Legion Square Garage', icon = 'garage', color = '#7c5cff', coords = vec4(216.0, -806.5, 30.77, 245.0) },
    { id = 'police', label = 'Police Department', icon = 'police', color = '#f5c542', coords = vec4(427.6, -979.6, 30.71, 90.0) },
    { id = 'hospital', label = 'Hospital', icon = 'hospital', color = '#e5484d', coords = vec4(298.6, -584.6, 43.26, 70.0) },
    { id = 'north', label = 'North Garage', icon = 'north', color = '#2fc4d6', coords = vec4(80.35, 6424.12, 31.67, 45.5) },
    { id = 'last', label = 'Last Location', icon = 'pin', color = '#7bd96a', last = true },
}

-- Where a character goes when it must use its last location but that was never saved (or is a bad save)
Config.Fallback = vec4(216.0, -806.5, 30.77, 245.0)

-- Preview camera: in front of where the player will face, looking back at the spot
Config.Camera = {
    distance = 14.0,
    height = 6.0,
    fov = 55.0,
    blendMs = 1200, -- fly between nearby spots
    flyMax = 800.0, -- farther than this jumps instead of flying (the map would not stream in time)
}
