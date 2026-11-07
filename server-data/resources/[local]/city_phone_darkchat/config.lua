Config = {}

Config.Phone = 'phone'

-- The item that puts DarkChat on the phone while it is carried
Config.Item = 'darkchat_usb'

-- Alias: letters, numbers, - and _
Config.AliasLength = { min = 3, max = 16 }

-- Room names: lowercase letters, numbers, - and _
Config.RoomLength = { min = 3, max = 24 }
Config.PasswordLength = 32

Config.MessageLength = 300

-- Hours before a message is deleted
Config.MessageHours = 24

-- Rooms one character can be in, and messages per page
Config.MaxRooms = 20
Config.PageSize = 50

-- Seconds between two messages
Config.MessageCooldown = 1
