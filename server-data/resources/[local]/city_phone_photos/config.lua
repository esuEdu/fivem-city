Config = {}

Config.Item = 'phone'

-- Photos each character can keep
Config.MaxPhotos = 300

-- Size of a photo (the game view is scaled down to fit) and the largest image accepted, in base64 characters
Config.Capture = { encoding = 'webp', maxWidth = 854, maxHeight = 480 }
Config.MaxDataLength = 400000

-- Seconds between two photos
Config.Cooldown = 1.5
