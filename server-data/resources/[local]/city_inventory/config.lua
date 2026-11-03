Config = {}

Config.Slots = 40
Config.MaxWeight = 30000 -- grams
Config.HotbarSlots = 5
Config.OpenKey = 'TAB'

Config.AutosaveMinutes = 5

-- Item categories, set with `category` in data/items.lua. Weapons and ammo get theirs automatically;
-- items without one are 'misc'. The color tints the item's slot in the UI.
Config.Categories = {
    food = { label = 'Food', color = '#f5c542' },
    drink = { label = 'Drink', color = '#3ec7e0' },
    medical = { label = 'Medical', color = '#3ecf72' },
    weapon = { label = 'Weapon', color = '#e5484d' },
    ammo = { label = 'Ammo', color = '#f08c3a' },
    electronics = { label = 'Electronics', color = '#a371f7' },
    misc = { label = 'Misc', color = '#9aa0a6' },
}

-- Inventory actions (move, use) a player may send per second before the rest are refused
Config.ActionsPerSecond = 10

-- What the starter consumables do. hunger/thirst add to the 0-100 status, health to the ped's health.
Config.Consumables = {
    water = { thirst = 25 },
    sandwich = { hunger = 30 },
    bandage = { health = 15 },
}
