Config = {}

-- Same as the Qbox recipe's ox_inventory settings
Config.Slots = 50
Config.MaxWeight = 85000 -- grams
Config.HotbarSlots = 5
Config.OpenKey = 'TAB'

Config.AutosaveMinutes = 5

-- How close (meters) a player has to be to a stash's coords to open it, and how far they can walk while it's open
Config.StashDistance = 5.0

-- Item categories, set with `category` in data/items.lua. Weapons and ammo get theirs automatically;
-- items without one are 'misc'. The color tints the item's slot in the UI; the order is the order of the filter tabs.
Config.Categories = {
    { name = 'weapon', label = 'Weapons', color = '#e5484d' },
    { name = 'ammo', label = 'Ammo', color = '#f08c3a' },
    { name = 'food', label = 'Food', color = '#f5c542' },
    { name = 'drink', label = 'Drinks', color = '#3ec7e0' },
    { name = 'medical', label = 'Medical', color = '#3ecf72' },
    { name = 'drug', label = 'Drugs', color = '#e05fd0' },
    { name = 'tool', label = 'Tools', color = '#5b9cf5' },
    { name = 'electronics', label = 'Electronics', color = '#a371f7' },
    { name = 'valuable', label = 'Valuables', color = '#38d9a9' },
    { name = 'material', label = 'Materials', color = '#b08968' },
    { name = 'document', label = 'Documents', color = '#c9d1d9' },
    { name = 'misc', label = 'Misc', color = '#9aa0a6' },
}

-- Inventory actions (move, use) a player may send per second before the rest are refused
Config.ActionsPerSecond = 10

-- Most rounds one reload may load when the weapon has no `clip` in data/weapons.lua.
-- The client tells the server the magazine size; this caps it.
Config.MaxClip = 100

-- Crafting: drop one ingredient onto another in the inventory. Any two ingredients of a recipe start it; the player
-- needs all of them. duration (ms) shows a progress bar first.
Config.Recipes = {
    { ingredients = { { 'rolling_paper', 1 }, { 'weed_skunk', 1 } }, result = { 'joint', 1 }, duration = 3000 },
    { ingredients = { { 'metalscrap', 5 }, { 'rubber', 2 } }, result = { 'repairkit', 1 }, duration = 5000 },
}

-- Item sets for the /kit admin command. The first one is given when no name is typed.
Config.Kits = {
    { name = 'test', items = {
        { 'water', 5 },
        { 'sandwich', 5 },
        { 'bandage', 5 },
        { 'lockpick', 2 },
        { 'radio', 1 },
        { 'weapon_pistol', 1 },
        { 'ammo-9', 48 },
        { 'weapon_knife', 1 },
    } },
    { name = 'food', items = {
        { 'water', 10 },
        { 'sandwich', 10 },
        { 'burger', 5 },
        { 'sprunk', 5 },
    } },
    { name = 'weapons', items = {
        { 'weapon_pistol', 1 },
        { 'ammo-9', 96 },
        { 'weapon_knife', 1 },
        { 'at_flashlight', 1 },
        { 'at_suppressor_light', 1 },
        { 'at_clip_extended_pistol', 1 },
        { 'at_scope_large', 1 },
    } },
    { name = 'crafting', items = {
        { 'rolling_paper', 3 },
        { 'weed_skunk', 3 },
        { 'metalscrap', 10 },
        { 'rubber', 4 },
    } },
}
