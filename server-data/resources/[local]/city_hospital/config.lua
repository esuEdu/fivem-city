Config = {}

Config.Job = 'ambulance'
Config.JobType = 'ems'

-- The EMS tablet app (city_os): dashboard, calls, management and the records of revives and bills
Config.App = {
    id = 'ems',
    label = 'EMS',
    order = 31,
    icon = {
        glyph = 'M12 20.3S3.8 15.6 3.8 9.4A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 8.2 2.2c0 6.2-8.2 10.9-8.2 10.9zM7 12.2h2.6l1.4-2.4 2.1 4.6 1.3-2.2H17',
        colors = { '#ff7b7b', '#e5383b', '#9d1c20' },
        glyphColor = '#ffffff',
        tint = '#ff7b7b',
    },
    employer = 'Pillbox Medical',
    historyLimit = 60, -- records listed in the Records tab
    offerSeconds = 60, -- how long a job offer from the boss stays on the player's screen
}

-- Keys while down: E (hold) respawn, G send SOS, H desperate prayer (NPC ambulance). Control ids, not key names.
Config.Keys = { respawn = 38, sos = 47, pray = 74, dropBody = 73 }
Config.RespawnHoldMs = 2000

-- Animations reused from qbx_ambulancejob
Config.Anims = {
    bed = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' },
    cpr = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
    kneel = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },
    pill = { dict = 'mp_suicide', clip = 'pill' },
    carry = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman' },
    carried = { dict = 'nm', clip = 'firemans_carry' },
}

Config.Hospitals = {
    pillbox = {
        label = 'Pillbox Medical',
        blip = vec3(298.6, -584.5, 43.26),
        reception = vec4(308.19, -595.35, 43.29, 70.0),
        receptionist = `s_f_y_scrubs_01`,
        beds = {
            { coords = vec4(353.1, -584.6, 43.11, 152.08), model = 1631638868 },
            { coords = vec4(356.79, -585.86, 43.11, 152.08), model = 1631638868 },
            { coords = vec4(354.12, -593.12, 43.1, 336.32), model = 2117668672 },
            { coords = vec4(350.79, -591.8, 43.1, 336.32), model = 2117668672 },
            { coords = vec4(346.99, -590.48, 43.1, 336.32), model = 2117668672 },
            { coords = vec4(360.32, -587.19, 43.02, 152.08), model = -1091386327 },
            { coords = vec4(349.82, -583.33, 43.02, 152.08), model = -1091386327 },
            { coords = vec4(326.98, -576.17, 43.02, 152.08), model = -1091386327 },
        },
    },
    paleto = {
        label = 'Paleto Medical',
        blip = vec3(-250.0, 6315.0, 32.0),
        reception = vec4(-254.54, 6331.78, 32.43, 225.0),
        receptionist = `s_f_y_scrubs_01`,
        beds = {
            { coords = vec4(-252.43, 6312.25, 32.34, 313.48), model = 2117668672 },
            { coords = vec4(-247.04, 6317.95, 32.34, 134.64), model = 2117668672 },
            { coords = vec4(-255.98, 6315.67, 32.34, 313.91), model = 2117668672 },
        },
    },
}

Config.Blip = { sprite = 61, color = 1, scale = 0.8 }

-- EMS job places
Config.Duty = { vec3(311.18, -599.25, 43.29), vec3(-254.88, 6324.5, 32.58) }
Config.Armory = { vec3(309.93, -602.94, 43.29) }
Config.Lockers = { vec3(309.78, -596.6, 43.29) }

-- Garages: where the menu is and where the vehicle appears; kind = 'car' or 'heli'
Config.Garages = {
    { kind = 'car', menu = vec3(294.58, -574.76, 43.18), spawn = vec4(294.578, -574.761, 43.179, 35.79) },
    { kind = 'car', menu = vec3(-234.28, 6329.16, 32.15), spawn = vec4(-234.28, 6329.16, 32.15, 222.5) },
    { kind = 'heli', menu = vec3(351.58, -587.45, 74.16), spawn = vec4(351.58, -587.45, 74.16, 160.5) },
    { kind = 'heli', menu = vec3(-475.43, 5988.35, 31.72), spawn = vec4(-475.43, 5988.353, 31.716, 31.34) },
}

-- Job vehicles: lowest job grade that may take each one
Config.Vehicles = {
    car = { { model = 'ambulance', label = 'Ambulance', grade = 0 } },
    heli = { { model = 'polmav', label = 'Air ambulance', grade = 2 } },
}

-- Pillbox elevator: main floor <-> roof helipad
Config.Elevators = { { main = vec4(298.62, -599.66, 43.29, 70.0), roof = vec4(338.54, -583.88, 74.17, 250.0) } }

-- NPC ambulance ("Desperate prayer")
Config.Npc = {
    vehicle = `ambulance`,
    medic = `s_m_m_paramedic_01`,
    spawnDistance = 200.0,
    driveTimeout = 60, -- seconds before the medic gives up driving and walks over
}

-- Self-use items: progress time (ms), health added, bleed levels removed; painkillers hide injury effects for a while
Config.Items = {
    bandage = { time = 4000, health = 10, bleed = 1, anim = 'pill' },
    painkillers = { time = 3000, painSeconds = 120, anim = 'pill' },
    ifaks = { time = 5000, health = 30, bleed = 2, painSeconds = 60, anim = 'pill' },
}
