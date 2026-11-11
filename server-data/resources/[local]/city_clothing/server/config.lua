-- Server-only: prices and blocked pieces. The shop page gets the prices to show them, but only these are charged.
return {
    -- Per category changed (any drawable or color of it), by Config.Categories id
    prices = {
        tops = 120,
        undershirts = 50,
        arms = 40,
        pants = 90,
        shoes = 80,
        neck = 35,
        bags = 60,
        masks = 70,
        hats = 45,
        glasses = 40,
        earrings = 30,
        watches = 120,
        bracelets = 40,

        hair = 60,
        beard = 30,
        eyebrows = 20,
        chestHair = 20,
        makeup = 35,
        blush = 20,
        lipstick = 20,

        -- Every tattoo (tattoo parlor and the barber's hair details); removing one is free
        tattoo = 250,
    },

    -- Pieces players can't buy (uniforms, job gear). Per sex: [component id or 'p'..prop id] = { drawable, { from, to }, ... }
    blocked = {
        m = {},
        f = {},
    },

    -- Accounts a purchase may be paid from (city_economy reasons clothing-shop / barber-shop)
    accounts = { cash = true, bank = true },
}
