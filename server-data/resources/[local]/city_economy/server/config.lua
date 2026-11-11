-- Server-only economy settings: never listed in files, so players can't read them
return {
    -- What a new character starts with (BANCO_DESIGN.md 3)
    startingCash = 2000,
    startingBank = 498000, -- V1 test: $500,000 in all

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
            { reason = '^paycheck$', credit = true, perHour = 120000 }, -- $20,000 every 10 minutes
        },
        city_inventory = {
            { reason = '^shop%-refund$', credit = true, perHour = 500000 },
            { reason = '^shop%-', debit = true },
            -- RemoveItem('money') from scripts like ox_fuel. Never credit: AddItem('money') from any script would print cash.
            { reason = '^inventory%-cash%-item$', debit = true },
        },
        -- Hospital fees: respawn, bed, reception, NPC ambulance
        city_hospital = {
            { reason = '^hospital%-', debit = true },
        },
        -- Impound lot fee, and its refund when the car can't be spawned
        city_garages = {
            { reason = '^garage%-depot$', debit = true },
            { reason = '^garage%-refund$', credit = true, perHour = 50000 },
        },
        -- Dealership: buying a car (in full or the down payment), paying a financing off, and the refund when the car
        -- can't be registered
        city_dealership = {
            { reason = '^dealership%-buy$', debit = true },
            { reason = '^dealership%-payoff$', debit = true },
            { reason = '^dealership%-refund$', credit = true, perHour = 5000000 },
        },
        -- Fishing: selling the catch, tournament prizes, the shop (licence, gear, repairs, skill reset) and the boat
        -- rental (fee, deposit, and the deposit back)
        city_fishing = {
            { reason = '^fishing%-sell$', credit = true, perHour = 150000 },
            { reason = '^fishing%-tournament$', credit = true, perHour = 50000 },
            { reason = '^fishing%-boat%-refund$', credit = true, perHour = 20000 },
            { reason = '^fishing%-shop$', debit = true },
            { reason = '^fishing%-licence$', debit = true },
            { reason = '^fishing%-repair$', debit = true },
            { reason = '^fishing%-respec$', debit = true },
            { reason = '^fishing%-boat%-rent$', debit = true },
            { reason = '^fishing%-boat%-deposit$', debit = true },
        },
        -- Robberies: picking up the cash bag of a blown ATM or a robbed 24/7 (anyone may pick it up)
        city_robbery = {
            { reason = '^robbery%-atm$', credit = true, perHour = 1000000 },
            { reason = '^robbery%-store$', credit = true, perHour = 2000000 },
        },
        -- Mining: selling ore and ingots, gems and jewellery at Vangelico, the crime buyer; the shop (licences, tools,
        -- repairs, skill reset), smelter fees, coal, dynamite, opening geodes and the jeweller's work
        city_mining = {
            { reason = '^mining%-sell$', credit = true, perHour = 150000 },
            { reason = '^mining%-jeweler%-sell$', credit = true, perHour = 150000 },
            { reason = '^mining%-crime$', credit = true, perHour = 100000 },
            { reason = '^mining%-shop$', debit = true },
            { reason = '^mining%-licence$', debit = true },
            { reason = '^mining%-explosives%-licence$', debit = true },
            { reason = '^mining%-repair$', debit = true },
            { reason = '^mining%-respec$', debit = true },
            { reason = '^mining%-smelter$', debit = true },
            { reason = '^mining%-coal$', debit = true },
            { reason = '^mining%-dynamite$', debit = true },
            { reason = '^mining%-geode$', debit = true },
            { reason = '^mining%-jeweler$', debit = true },
        },
        -- Phone Market: the fee to publish or renew an ad
        city_phone_market = {
            { reason = '^market%-ad$', debit = true },
        },
        -- Staff app: Give money (admins, a reason is required and written to the staff log)
        city_staff = {
            { reason = '^staff%-grant$', credit = true, perHour = 1000000 },
        },
        -- Clothing stores, barbers and tattoo parlours: the bag paid at the till
        city_clothing = {
            { reason = '^clothing%-shop$', debit = true },
            { reason = '^barber%-shop$', debit = true },
            { reason = '^tattoo%-shop$', debit = true },
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
