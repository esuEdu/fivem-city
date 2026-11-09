Config = {}

Config.Item = 'phone'

-- Back camera zoom (field of view: smaller = closer)
Config.Fov = { min = 15.0, max = 70.0, default = 50.0, step = 4.0 }

-- Mouse look speed and how far up/down the back camera turns
Config.LookSpeed = 6.0
Config.Pitch = { min = -70.0, max = 70.0 }

-- Selfie: a camera at arm's length in front of the face (meters from the head), so the player can still walk. The
-- phone prop goes in the right hand; the arm animation plays only if the game has it.
Config.Selfie = {
    distance = 0.75,
    side = 0.15,
    height = 0.05,
    fov = 55.0,
    prop = { model = `prop_npc_phone_02`, bone = 28422 },
    anim = { dict = 'cellphone@self', clip = 'selfie' },
}

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
