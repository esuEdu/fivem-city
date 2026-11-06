-- Server-only economy settings: never listed in files, so players can't read them
return {
    -- What a new character starts with (BANCO_DESIGN.md 3)
    startingCash = 2000,
    startingBank = 18000,

    -- Hard ceilings, far below 2^53 so the NUI never loses precision
    maxTransaction = 5000000,
    maxBalance = 1000000000,

    -- Seconds a write waits for another write on the same account before giving up
    lockTimeout = 5,

    -- The only places money may come from or go to. Anything else is refused and logged.
    -- sources[resource] = list of { reason = Lua pattern, credit = bool, debit = bool, perHour = max credited per character per hour }
    sources = {
        city_economy = {
            { reason = '^starting$', credit = true },
        },
        qbx_core = {
            { reason = '^paycheck$', credit = true, perHour = 20000 },
        },
        city_inventory = {
            { reason = '^shop%-refund$', credit = true, perHour = 500000 },
            { reason = '^shop%-', debit = true },
            -- RemoveItem('money') from scripts like ox_fuel. Never credit: AddItem('money') from any script would print cash.
            { reason = '^inventory%-cash%-item$', debit = true },
        },
        ['illenium-appearance'] = {
            { reason = '^unknown$', debit = true },
        },
    },

    -- Net events no real client ever sends: whoever triggers one is running a cheat menu
    honeypots = {
        'bank:addMoney',
        'bank:deposit',
        'banking:addMoney',
        'economy:giveMoney',
        'esx:giveMoney',
        'esx_society:depositMoney',
        'qb-banking:server:addMoney',
        'qb-bossmenu:server:depositMoney',
        'QBCore:Server:AddMoney',
        'city_economy:server:addMoney',
        'city_bank:server:addMoney',
        'money:add',
        'shop:additem',
        'inventory:giveItem',
    },
}
