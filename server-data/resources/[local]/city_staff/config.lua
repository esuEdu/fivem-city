Config = {}

-- Staff levels, lowest first: the ACE each one has (server.cfg: add_ace group.support support allow, ...). A level
-- includes everything below it. Staff have their level on every character of their account (ACEs are per license).
Config.Levels = { 'support', 'mod', 'admin' }

-- The lowest level that may do each thing. Remove a line to turn that tool off.
Config.Permissions = {
    -- the app (dashboard and player list), reports, and the ratings players gave staff
    app = 'support',
    reports = 'support',
    ratings = 'support',

    -- on a player
    ['goto'] = 'support',
    bring = 'support',
    heal = 'support',
    revive = 'support',
    freeze = 'support',
    warn = 'support',
    spectate = 'mod',
    inventory = 'mod',
    cuff = 'mod',
    kick = 'mod',
    ban = 'mod',          -- up to Config.MaxBanHours
    banLong = 'admin',    -- longer bans and permanent ones
    kill = 'admin',
    clothing = 'admin',
    bucket = 'admin',
    setJob = 'admin',
    setGang = 'admin',
    setStats = 'admin',   -- armor, hunger, thirst
    giveMoney = 'admin',  -- cash or bank, with a reason (city_economy caps it per character per hour)

    -- ban list, staff log, and the Team tab (how each staff member is doing)
    unban = 'admin',
    log = 'admin',
    team = 'admin',
    goals = 'admin',      -- change the report goals (Team tab)

    -- on themselves
    noclip = 'mod',
    invisible = 'mod',
    names = 'mod',
    blips = 'mod',
    godmode = 'admin',

    -- vehicles
    spawnVehicle = 'admin',

    -- server tools: city_clothing's photo tool (a picture of every clothing piece for the shops) and the doorlock panel
    clothingPhotos = 'admin',
    doorlock = 'admin', -- ox_doorlock's panel: create, edit and delete locked doors
}

-- Most one Give money can add (the economy also caps staff grants at $1,000,000 per character per hour)
Config.MaxGiveMoney = 1000000

-- Longest ban (hours) for staff without banLong
Config.MaxBanHours = 168

-- Ban lengths offered in the app, in hours (0 = permanent, only with banLong)
Config.BanLengths = { 1, 6, 24, 72, 168, 720, 0 }

-- /report: shortest gap between two reports from one player (seconds), longest message, and how many reports may be
-- open at once (new ones are refused above that)
Config.ReportCooldown = 60
Config.ReportMaxLength = 300
Config.MaxReports = 100

-- How many staff log entries the app shows
Config.LogLimit = 200

-- Ratings: after staff close a report, the player who sent it is asked to rate them (1-5 stars, these tags, a comment).
-- They have this many minutes to answer.
Config.RatingMinutes = 10
Config.RatingTags = { 'Fast', 'Polite', 'Fixed it', "Didn't help" }

-- Dashboard and Team: reports a staff member aims to close per period. These are the defaults; admins change them in
-- the Team tab, which keeps its own values from then on.
Config.Goals = { today = 5, week = 30, month = 120 }

-- Highest routing bucket staff can put a player in
Config.MaxBucket = 1000

-- Staff blips: how often (seconds) the server sends every player's position to staff with blips on
Config.BlipSeconds = 3

-- Player names over heads: how far (meters) they are drawn
Config.NameDistance = 60.0

-- Noclip speeds (meters per frame): normal, holding Shift, holding Alt
Config.NoclipSpeeds = { normal = 0.6, fast = 2.5, slow = 0.12 }

-- The app's icon on the tablet
Config.App = {
    id = 'staff',
    label = 'Staff',
    order = 90,
    icon = {
        glyph = 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6zM9 12l2 2 4-4',
        colors = { '#ff8a8a', '#e5484d', '#a3262b' },
        glyphColor = '#ffffff',
        tint = '#ff8a8a',
    },
}
