-- Plain data only: qbx_core also loads this file (bridge/qb/shared/main.lua), so no Config or locale() here.
-- Fields follow ox_inventory's format: label, weight (grams), stack, close, consume, description, client.image
-- plus category (a key of Config.Categories, default 'misc')
return {
    phone = {
        label = 'Phone',
        weight = 190,
        category = 'electronics',
        stack = false,
    },

    water = {
        label = 'Water',
        weight = 500,
        category = 'drink',
        consume = 1,
    },

    sandwich = {
        label = 'Sandwich',
        weight = 300,
        category = 'food',
        consume = 1,
        client = { image = 'burger.png' },
    },

    bandage = {
        label = 'Bandage',
        weight = 115,
        category = 'medical',
        consume = 1,
    },
}
