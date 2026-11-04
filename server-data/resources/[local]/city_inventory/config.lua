Config = {}

-- Same as the Qbox recipe's ox_inventory settings
Config.Slots = 50
Config.MaxWeight = 85000 -- grams
Config.HotbarSlots = 5
Config.OpenKey = 'TAB'

-- Blur the game behind the inventory while it's open, fading in and out over this many ms
Config.ScreenBlur = true
Config.ScreenBlurFadeMs = 250

Config.AutosaveMinutes = 5

-- How close (meters) a player has to be to a stash's coords to open it, and how far they can walk while it's open
Config.StashDistance = 5.0

-- Trunks and gloveboxes. Sizes by vehicle type (GetVehicleType: automobile, bike, boat, heli, plane, trailer, ...;
-- a type left out has none), with bigger ones for some models. The player has to stand within TrunkDistance of the car.
Config.TrunkDistance = 4.0
Config.VehicleStorage = {
    trunk = {
        automobile = { slots = 30, maxWeight = 100000 },
        boat = { slots = 30, maxWeight = 120000 },
        heli = { slots = 20, maxWeight = 60000 },
        plane = { slots = 40, maxWeight = 150000 },
        trailer = { slots = 60, maxWeight = 500000 },
    },
    glovebox = {
        automobile = { slots = 5, maxWeight = 10000 },
        boat = { slots = 5, maxWeight = 10000 },
        heli = { slots = 5, maxWeight = 10000 },
        plane = { slots = 5, maxWeight = 10000 },
    },
    models = {
        [`burrito3`] = { trunk = { slots = 50, maxWeight = 250000 } },
        [`rumpo`] = { trunk = { slots = 50, maxWeight = 250000 } },
        [`speedo`] = { trunk = { slots = 50, maxWeight = 250000 } },
        [`youga`] = { trunk = { slots = 50, maxWeight = 250000 } },
        [`mule`] = { trunk = { slots = 80, maxWeight = 500000 } },
        [`benson`] = { trunk = { slots = 100, maxWeight = 800000 } },
        [`pounder`] = { trunk = { slots = 100, maxWeight = 1000000 } },
    },
}

-- Items on the ground: size of a drop, how close the player has to be, and how long an unattended drop stays
Config.DropSlots = 30
Config.DropMaxWeight = 100000
Config.DropDistance = 3.0
Config.DropMinutes = 10
Config.DropModel = `prop_med_bag_01b`

-- Trading between players: how close they have to stay, and how many item slots each side can offer
Config.TradeDistance = 3.0
Config.TradeSlots = 10
Config.TradeMaxWeight = 1000000

-- Shops (data/shops.lua): how close the player has to be, and the qbx money accounts tried in order to pay
Config.ShopDistance = 5.0
Config.ShopAccounts = { 'cash', 'bank' }

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

-- A gun holds a full magazine plus this many spare magazines (16/128 for a 16-round pistol); R reloads from the spare
-- rounds, and only takes ammo items from the inventory once they're gone. MaxGunAmmo caps the total (the game's limit).
Config.ReserveMagazines = 8
Config.MaxGunAmmo = 250

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
