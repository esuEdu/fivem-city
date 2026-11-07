Config = {}

Config.Item = 'phone'

-- Back camera zoom (field of view: smaller = closer)
Config.Fov = { min = 15.0, max = 70.0, default = 50.0, step = 4.0 }

-- Mouse look speed and how far up/down the back camera turns
Config.LookSpeed = 6.0
Config.Pitch = { min = -70.0, max = 70.0 }

-- Filters: the game's own timecycle modifiers (tune the names here if one looks off)
Config.Filters = {
    { key = 'original' },
    { key = 'bw', modifier = 'CAMERA_BW' },
    { key = 'vintage', modifier = 'NG_filmic04' },
    { key = 'warm', modifier = 'NG_filmic02' },
    { key = 'cold', modifier = 'hud_def_desat_cold' },
    { key = 'noir', modifier = 'NG_filmnoir_BW01' },
}

-- Controls (game control ids)
Config.Keys = {
    shoot = 24, -- left mouse
    shootAlt = 191, -- enter
    selfie = 38, -- E
    filterLeft = 174, -- arrow left
    filterRight = 175, -- arrow right
    zoomIn = 241, -- wheel up
    zoomOut = 242, -- wheel down
    hud = 74, -- H
    exit = 177, -- backspace
    exitAlt = 25, -- right mouse
}
