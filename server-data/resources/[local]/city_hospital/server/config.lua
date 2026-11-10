-- Server-only hospital rules. Low test prices for now; tune before launch.
return {
    prices = {
        respawn = 5, -- respawning at the hospital
        bed = 1, -- lying in a bed to get treated
        reception = 5, -- NPC reception when no EMS is on duty
        prayer = 10, -- NPC ambulance
        maxBill = 100000, -- most an EMS can bill in one go
    },

    times = {
        downWait = 30, -- seconds down before the hospital respawn unlocks (design: 600)
        bedTreatment = 10, -- seconds in a bed before being healed
        receptionTreatment = 15,
        npcMinimum = 15, -- the NPC ambulance can't revive faster than this, whatever the client says
        npcTimeout = 180,
        emsRevive = 7, -- EMS revive progress (the client bar is 8 s)
        emsTreat = 4,
        sosCooldown = 60,
        callExpire = 900,
        billCooldown = 10,
    },

    ranges = {
        finalize = 2.0, -- /finalizado reach
        interact = 3.0, -- pulse, carry, EMS actions
        place = 3.0, -- duty, armory, lockers, garages, reception, beds
    },

    -- What the EMS armory sells (paid like any shop)
    armory = {
        { name = 'bandage', price = 1 },
        { name = 'painkillers', price = 1 },
        { name = 'ifaks', price = 2 },
        { name = 'firstaid', price = 5 },
        { name = 'radio', price = 1 },
        { name = 'weapon_flashlight', price = 1 },
        { name = 'weapon_fireextinguisher', price = 1 },
    },

    locker = { slots = 30, weight = 100000 },

    -- Reference prices the EMS app shows, to charge patients with a bill (only a guide: the bill amount is the EMS's)
    billing = {
        { key = 'revive', price = 500 },
        { key = 'treatment', price = 250 },
        { key = 'transport', price = 300 },
        { key = 'checkup', price = 150 },
    },

    -- Documents a hospital respawn hands back new (everything else carried is lost); qbx_idcard fills them in
    respawnDocuments = { 'id_card', 'driver_license' },
}
