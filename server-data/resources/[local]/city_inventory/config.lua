Config = {}

Config.Slots = 40
Config.MaxWeight = 30000 -- grams
Config.HotbarSlots = 5
Config.OpenKey = 'TAB'

Config.AutosaveMinutes = 5

-- Item categories, set with `category` in data/items.lua. Weapons and ammo get theirs automatically;
-- items without one are 'misc'. The color tints the item's slot in the UI; the order is the order of the filter tabs.
Config.Categories = {
    { name = 'weapon', label = 'Weapons', color = '#e5484d' },
    { name = 'ammo', label = 'Ammo', color = '#f08c3a' },
    { name = 'food', label = 'Food', color = '#f5c542' },
    { name = 'drink', label = 'Drinks', color = '#3ec7e0' },
    { name = 'medical', label = 'Medical', color = '#3ecf72' },
    { name = 'electronics', label = 'Electronics', color = '#a371f7' },
    { name = 'misc', label = 'Misc', color = '#9aa0a6' },
}

-- Inventory actions (move, use) a player may send per second before the rest are refused
Config.ActionsPerSecond = 10

-- What the starter consumables do. hunger/thirst add to the 0-100 status, health to the ped's health.
Config.Consumables = {
    water = { thirst = 25 },
    sandwich = { hunger = 30 },
    bandage = { health = 15 },
}
