-- Server-only prison rules. Low numbers are for testing; tune before launch.
return {
    -- One month of sentence = one minute played inside (offline time doesn't count)
    secondsPerMonth = 60,
    maxMonths = 240, -- cap on a sentence, escape debt included

    -- Jobs take months off, but never more than this share of the sentence
    reduceCap = 0.5,
    jobs = {
        cleaning = { months = 1, seconds = 8 },
        kitchen = { months = 1, seconds = 10 },
        electrical = { months = 2, seconds = 6 },
    },
    taskCooldown = 15, -- seconds between two finished tasks

    -- Free food and water inside: how much hunger/thirst (0-100) and how often per inmate (seconds)
    water = { amount = 35, cooldown = 60 },
    tray = { amount = 45, cooldown = 600 },

    -- Contraband search spots: chance of finding something, cooldowns (seconds), what turns up (weights)
    contraband = {
        seconds = 6,
        chance = 60,
        spotCooldown = 900,
        playerCooldown = 120,
        loot = {
            { item = 'prison_scrap', weight = 35 },
            { item = 'prison_cloth', weight = 25 },
            { item = 'prison_wire', weight = 20 },
            { item = 'prison_battery', weight = 10 },
            { item = 'prison_circuit', weight = 10 },
        },
    },

    -- Escapes: the time left is owed times this when caught again, in a warrant on the MDT
    escapeMultiplier = 2,
    warrantDays = 7,
    entryGrace = 30, -- seconds after entering before leaving the circle counts (teleport, loading)
    escapeCheck = 5, -- seconds between checks

    -- Gate hacks: needs one of these items; the alarm and losing the item are chances in percent
    hack = {
        items = { 'prison_jammer', 'trojan_usb' },
        seconds = 5,
        openSeconds = 20,
        terminalCooldown = 600,
        minPolice = 0,
        alarm = { success = 100, fail = 25 },
        loseItem = { success = 100, fail = 50 },
        alarmSeconds = 120,
    },

    -- Belongings: cash stays in the pocket (it is the ledger's); these go to the police evidence locker for good.
    -- Weapons go there too unless registered to the inmate in the MDT.
    cashItem = 'money',
    evidenceStash = 'city_police_evidence',
    lockerSlots = 60,
    lockerWeight = 1000000,
    illegal = {
        names = {
            'black_money', 'markedbills', 'lockpick', 'advancedlockpick', 'trojan_usb', 'gatecrack', 'thermite',
            'drill', 'electronickit', 'security_card_01', 'security_card_02', 'crack_baggy', 'cokebaggy',
            'coke_brick', 'coke_small_brick', 'xtcbaggy', 'meth', 'oxy', 'joint',
            'prison_jammer', 'burner_phone', 'weapon_switchblade',
        },
        patterns = { '^weed_' },
    },

    -- Seconds between two prison computer actions by one officer
    computerThrottle = 1,
    historyLimit = 50,
}
