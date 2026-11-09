Config = {}

-- The drug gangs (qbx_core shared/gangs.lua names): only their members see the app, and only they may use city_drugs'
-- labs and bulk deals. Other gangs get their own apps for their own business.
Config.Gangs = { 'cartel' }

-- The lowest gang grade that may do each thing (qbx_core shared/gangs.lua: 0 Recruit, 1 Enforcer, 2 Shot Caller,
-- 3 Boss). Promoting, demoting and firing only ever reach members below your own grade. Remove a line to turn it off.
Config.Permissions = {
    app = 0,        -- overview, members list and the drugs guide
    recruit = 2,    -- invite a nearby player without a gang
    setGrade = 2,   -- promote or demote
    fire = 2,
    log = 1,        -- the gang's log (hires, promotions, sales)
}

-- Recruiting: how close (meters) the player must stand, and how long they have to answer the invite (seconds)
Config.InviteDistance = 5.0
Config.InviteSeconds = 30

-- Performance periods the app offers (days) and the one it opens on; the daily chart shows this many days
Config.Periods = { 1, 7, 30 }
Config.StatsDays = 7
Config.ChartDays = 14

-- How many log entries the app shows
Config.LogLimit = 100

-- Resources allowed to report members' sales and batches with exports.city_gangs:Record
Config.RecordFrom = { city_drugs = true }

-- The app's icon on the tablet
Config.App = {
    id = 'gang',
    label = 'Cartel',
    order = 80,
    icon = {
        glyph = 'M12 2.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 15.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.8zM8 21.5h8',
        colors = { '#c4a5ff', '#8b5cf6', '#5b21b6' },
        glyphColor = '#ffffff',
        tint = '#c4a5ff',
    },
}
