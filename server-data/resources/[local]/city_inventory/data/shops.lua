-- Shops opened from the world, with ox_inventory's default locations and items from data/items.lua.
-- name: panel title. blip: map blip on each location. groups: job/gang -> lowest grade (nil = everyone).
-- inventory: { name, price, count? (stock, nil = unlimited), metadata?, license? (qbx licence), grade?, currency? (an item
-- paid with instead of money) }. locations: where the player can open it (ox_target zone). model: props that open it.
-- ped: a shopkeeper model standing at each location (locations are then vec4, the w is the heading).
return {
    -- The basics a new character needs, almost free, outside by the Legion Square ATMs. Coordinates placed without the
    -- game open: check them in game with /coords (city_base).
    Essentials = {
        name = 'City Essentials',
        blip = { id = 52, colour = 5, scale = 0.8 },
        ped = `a_m_y_business_02`,
        inventory = {
            { name = 'phone', price = 1 },
            { name = 'tablet', price = 1 },
            { name = 'radio', price = 1 },
            { name = 'darkchat_usb', price = 1 }, -- V1: DarkChat's USB is sold here too
            { name = 'c4', price = 1 }, -- V1: C4 for testing ATM robberies (city_robbery)
        },
        locations = {
            vec4(150.26, -1037.47, 29.34, 340.0),
        },
    },

    General = {
        name = '24/7',
        blip = { id = 59, colour = 69, scale = 0.8 },
        inventory = {
            { name = 'water', price = 10 },
            { name = 'sprunk', price = 10 },
            { name = 'coffee', price = 8 },
            { name = 'sandwich', price = 15 },
            { name = 'burger', price = 20 },
            { name = 'lighter', price = 5 },
            { name = 'rolling_paper', price = 2 },
            { name = 'bandage', price = 25 },
            { name = 'phone', price = 500 },
            { name = 'radio', price = 250 },
        },
        locations = {
            vec3(25.7, -1347.3, 29.49),
            vec3(-3038.71, 585.9, 7.9),
            vec3(-3241.47, 1001.14, 12.83),
            vec3(1728.66, 6414.16, 35.03),
            vec3(1697.99, 4924.4, 42.06),
            vec3(1961.48, 3739.96, 32.34),
            vec3(547.79, 2671.79, 42.15),
            vec3(2679.25, 3280.12, 55.24),
            vec3(2557.94, 382.05, 108.62),
            vec3(373.55, 325.56, 103.56),
        },
    },

    Liquor = {
        name = 'Liquor Store',
        blip = { id = 93, colour = 69, scale = 0.8 },
        inventory = {
            { name = 'water', price = 10 },
            { name = 'beer', price = 15 },
            { name = 'wine', price = 30 },
            { name = 'vodka', price = 40 },
            { name = 'whiskey', price = 45 },
        },
        locations = {
            vec3(1135.808, -982.281, 46.415),
            vec3(-1222.915, -906.983, 12.326),
            vec3(-1487.553, -379.107, 40.163),
            vec3(-2968.243, 390.910, 15.043),
            vec3(1166.024, 2708.930, 38.157),
            vec3(1392.562, 3604.684, 34.980),
            vec3(-1393.409, -606.624, 30.319),
        },
    },

    YouTool = {
        name = 'YouTool',
        blip = { id = 402, colour = 69, scale = 0.8 },
        inventory = {
            { name = 'lockpick', price = 50 },
            { name = 'screwdriverset', price = 150 },
            { name = 'repairkit', price = 250 },
            { name = 'jerry_can', price = 200 },
            { name = 'binoculars', price = 300 },
            { name = 'zipties', price = 40 },
            { name = 'head_bag', price = 60 },
            { name = 'pos_terminal', price = 3000 },
        },
        locations = {
            vec3(2748.0, 3473.0, 55.67),
            vec3(342.99, -1298.26, 32.51),
        },
    },

    Ammunation = {
        name = 'Ammunation',
        blip = { id = 110, colour = 69, scale = 0.8 },
        inventory = {
            { name = 'ammo-9', price = 5 },
            { name = 'WEAPON_KNIFE', price = 200 },
            { name = 'WEAPON_BAT', price = 100 },
            { name = 'WEAPON_PISTOL', price = 1000, metadata = { registered = true }, license = 'weapon' },
        },
        locations = {
            vec3(-662.180, -934.961, 21.829),
            vec3(810.25, -2157.60, 29.62),
            vec3(1693.44, 3760.16, 34.71),
            vec3(-330.24, 6083.88, 31.45),
            vec3(252.63, -50.00, 69.94),
            vec3(22.56, -1109.89, 29.80),
            vec3(2567.69, 294.38, 108.73),
            vec3(-1117.58, 2698.61, 18.55),
            vec3(842.44, -1033.42, 28.19),
        },
    },

    BlackMarketArms = {
        name = 'Black Market (Arms)',
        inventory = {
            { name = 'WEAPON_DAGGER', price = 5000, metadata = { registered = false }, currency = 'black_money' },
            { name = 'WEAPON_CERAMICPISTOL', price = 50000, metadata = { registered = false }, currency = 'black_money' },
            { name = 'at_suppressor_light', price = 50000, currency = 'black_money' },
            { name = 'ammo-rifle', price = 1000, currency = 'black_money' },
            { name = 'ammo-rifle2', price = 1000, currency = 'black_money' },
        },
        locations = {
            vec3(309.09, -913.75, 56.46),
        },
    },

    VendingMachineDrinks = {
        name = 'Vending Machine',
        inventory = {
            { name = 'water', price = 10 },
            { name = 'sprunk', price = 10 },
        },
        model = {
            `prop_vend_soda_02`, `prop_vend_fridge01`, `prop_vend_water_01`, `prop_vend_soda_01`,
        },
    },
}
