Config = {}

Config.Slots = 40
Config.MaxWeight = 30000 -- grams
Config.HotbarSlots = 5
Config.OpenKey = 'TAB'

Config.AutosaveMinutes = 5

-- Inventory actions (move, use) a player may send per second before the rest are refused
Config.ActionsPerSecond = 10

-- What the starter consumables do. hunger/thirst add to the 0-100 status, health to the ped's health.
Config.Consumables = {
    water = { thirst = 25 },
    sandwich = { hunger = 30 },
    bandage = { health = 15 },
}
