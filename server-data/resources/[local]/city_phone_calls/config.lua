Config = {}

-- The phone item (calls need it on both ends)
Config.Item = 'phone'

-- Seconds a call rings before it counts as missed
Config.RingSeconds = 30

-- People in one call, conference included
Config.MaxMembers = 4

-- Sharing your contact: how close the other person must be (meters)
Config.ShareDistance = 5.0

Config.MaxContacts = 200
Config.MaxBlocked = 100
Config.RecentsKept = 50

-- Phone numbers: digits only, this many
Config.NumberLength = { min = 3, max = 15 }
Config.NameLength = 30
