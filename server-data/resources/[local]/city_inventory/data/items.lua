-- Plain data only: qbx_core also loads this file (bridge/qb/shared/main.lua), so no Config or locale() here.
-- Fields follow ox_inventory's format: label, weight (grams), stack, close, consume, description, client.image
return {
    phone = {
        label = 'Phone',
        weight = 190,
        stack = false,
    },

    water = {
        label = 'Water',
        weight = 500,
        consume = 1,
    },

    sandwich = {
        label = 'Sandwich',
        weight = 300,
        consume = 1,
    },

    bandage = {
        label = 'Bandage',
        weight = 115,
        consume = 1,
    },
}
