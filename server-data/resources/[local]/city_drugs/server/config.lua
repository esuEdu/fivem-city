-- Server-only numbers: rewards, prices and chances players shouldn't read from the client files.
-- Every payout is the black_money item, never clean cash.
return {
    payItem = 'black_money',

    -- Police on duty (job type 'leo') needed before anything can be sold; 0 lets it run with no police online
    minPolice = { corner = 0, deal = 0 },

    -- Players of these job types can't take part while on duty
    blockedJobTypes = { leo = true },

    -- Only drug gang members (city_gangs Config.Gangs) may do these; picking and corner selling stay open to anyone
    gangOnly = { labs = true, deals = true },

    -- The three drugs, cheapest and safest first. The more a drug pays, the more it draws the police: each act has a
    -- base chance (percent) of a police call, and a sale adds one point per `perPoint` dollars, up to `max`.
    -- `refuse` is the chance a local who turns you down calls it in.
    drugs = {
        weed = { label = 'Weed', order = 1, level = 'low', pick = 0, lab = 2, sale = 3, refuse = 15, perPoint = 150, max = 20 },
        coke = { label = 'Cocaine', order = 2, level = 'medium', pick = 3, lab = 5, sale = 6, refuse = 30, perPoint = 100, max = 40 },
        meth = { label = 'Meth', order = 3, level = 'high', pick = 8, lab = 10, sale = 10, refuse = 45, perPoint = 60, max = 60 },
    },

    -- What one pick gives and how long until the spot regrows (the drug is the field's `drug` in config.lua)
    fields = {
        weed = { min = 1, max = 3, regrowMinutes = 5 },
        coca = { min = 2, max = 4, regrowMinutes = 6 },
        chemicals = { min = 1, max = 2, regrowMinutes = 8 },
    },

    corner = {
        -- per unit, and at most this many units in one sale
        prices = {
            weed_skunk = { drug = 'weed', min = 20, max = 35, maxUnits = 5 },
            cokebaggy = { drug = 'coke', min = 50, max = 80, maxUnits = 4 },
            meth = { drug = 'meth', min = 90, max = 140, maxUnits = 3 },
        },
        refuseChance = 30,
        -- seconds between offers by one player, minutes before the same local buys again, seconds to answer
        playerCooldown = 5,
        pedCooldownMinutes = 15,
        offerSeconds = 30,
    },

    deal = {
        orders = {
            { drug = 'weed', item = 'weed_brick', min = 1, max = 2, pricePerUnit = 700 },
            { drug = 'coke', item = 'coke_brick', min = 1, max = 1, pricePerUnit = 2200 },
            { drug = 'meth', item = 'meth', min = 10, max = 20, pricePerUnit = 150 },
        },
        minutes = 20,
        cooldownMinutes = 10,
        dropRadius = 5.0,
    },
}
