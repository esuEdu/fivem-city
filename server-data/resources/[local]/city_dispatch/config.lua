Config = {}

-- The city services every phone has as fixed contacts. jobType is the qbx job type that answers the calls (on duty).
-- ems goes to city_hospital's own calls list, so EMS see these together with the SOS of downed players; police goes to
-- city_police's calls (the MDT on the tablet), together with robbery alerts.
-- types are the kinds of call offered on the phone (the phone translates them; label is the in-game English text).
Config.Services = {
    police = {
        number = '190',
        label = 'Police',
        jobType = 'leo',
        mdt = true,
        types = { 'robbery', 'shooting', 'fight', 'accident', 'suspect', 'other' },
    },
    ems = {
        number = '192',
        label = 'EMS',
        jobType = 'ems',
        hospital = true,
        types = { 'injured', 'unconscious', 'accident', 'other' },
    },
    mechanic = {
        number = '555',
        label = 'Mechanic',
        jobType = 'mechanic',
        blip = { sprite = 446, colour = 47 },
        types = { 'breakdown', 'tyre', 'tow', 'other' },
    },
}

-- Order the services are listed in on the phone
Config.Order = { 'police', 'ems', 'mechanic' }

Config.TypeLabels = {
    robbery = 'Robbery',
    shooting = 'Shots fired',
    fight = 'Fight',
    accident = 'Accident',
    suspect = 'Suspicious person',
    injured = 'Injured person',
    unconscious = 'Unconscious person',
    breakdown = 'Breakdown',
    tyre = 'Flat tyre',
    tow = 'Tow',
    other = 'Other',
}

-- What the caller can write
Config.TextLength = 200

-- Seconds between two calls from one player to the same service
Config.CooldownSeconds = 60

-- Minutes a call stays open (and its blip on the map)
Config.ExpireMinutes = 15
