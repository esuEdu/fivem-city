Config = {}

Config.Item = 'phone'

-- People in a group chat (the creator included)
Config.MaxGroup = 10

Config.MaxLength = 500
Config.GroupNameLength = 30

-- Messages loaded per page of a chat, and chats in the list
Config.PageSize = 40
Config.MaxConversations = 60

-- Live location: how long it lasts and how often the others' maps update (seconds)
Config.LiveMinutes = 15
Config.LiveUpdateSeconds = 4

Config.Reactions = { 'heart', 'like', 'laugh', 'wow', 'question' }

Config.NumberLength = { min = 3, max = 15 }

-- A point sent from the map (the route set on the GPS) must be inside these game coordinates
Config.MapBounds = { minX = -4500.0, maxX = 4500.0, minY = -4500.0, maxY = 8500.0 }
