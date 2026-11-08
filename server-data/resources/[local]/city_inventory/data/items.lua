-- Plain data only: qbx_core also loads this file (bridge/qb/shared/main.lua), so no Config or locale() here.
-- Qbox's item list (txAdminRecipe items.lua) in ox_inventory's format, plus category (a key of Config.Categories).
-- client.status/anim/prop/usetime/event and client.add/remove work as in ox_inventory; see client/use.lua.
return {
    ['bandage'] = {
        label = 'Bandage',
        category = 'medical',
        weight = 115,
    },

    ['burger'] = {
        label = 'Burger',
        category = 'food',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        category = 'drink',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        category = 'tool',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
        category = 'misc',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        category = 'misc',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        category = 'misc',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        category = 'tool',
        weight = 160,
    },

    ['phone'] = {
        label = 'Phone',
        category = 'electronics',
        weight = 190,
        stack = false,
        consume = 0,
    },

    ['mustard'] = {
        label = 'Mustard',
        category = 'drink',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        category = 'drink',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        category = 'medical',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        category = 'misc',
        consume = 0,
    },

    -- The player's cash itself: city_economy's ledger follows every move of it (server/cashflow.lua). No weight, so
    -- cash from an ATM or a sale always fits.
    ['money'] = {
        label = 'Money',
        category = 'valuable',
        weight = 0,
        description = 'Cash',
    },

    ['black_money'] = {
        label = 'Dirty Money',
        category = 'valuable',
    },

    -- Issued only by city_bank at a branch; metadata.card_id points at the card row, nothing else is trusted
    ['bank_card'] = {
        label = 'Bank Card',
        category = 'document',
        weight = 5,
        stack = false,
        description = 'Use it at an ATM or a card machine',
    },

    -- Card machine: used through city_bank (CreateUseableItem) to charge a nearby player
    ['pos_terminal'] = {
        label = 'Card Machine',
        category = 'electronics',
        weight = 300,
        stack = false,
        consume = 0,
        description = 'Charge a nearby customer by card',
    },

    ['id_card'] = {
        label = 'Identification Card',
        category = 'document',
    },

    ['driver_license'] = {
        label = 'Drivers License',
        category = 'document',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
        category = 'document',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
        category = 'document',
    },

    ['radio'] = {
        label = 'Radio',
        category = 'electronics',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['tablet'] = {
        label = 'iFruit Pad',
        description = 'A tablet with apps for your job and the city. Opens with F2 while you carry it.',
        category = 'electronics',
        weight = 650,
        stack = false,
        close = true,
        consume = 0,
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        category = 'electronics',
        weight = 10000,
        allowArmed = true,
        client = {
            image = 'radiojammer.png',
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        category = 'electronics',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        category = 'tool',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        category = 'tool',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        category = 'tool',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        category = 'tool',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Repair Kit',
        category = 'tool',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'Advanced Repair Kit',
        category = 'tool',
        weight = 4000,
        client = { image = 'repairkit.png' },
    },

    ['diamond'] = {
        label = 'Diamond',
        category = 'valuable',
        weight = 50,
        description = 'A cut diamond.',
        client = { image = 'diamond_ring.png' },
    },

    ['diamond_ring'] = {
        label = 'Diamond Ring',
        category = 'valuable',
        weight = 100,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        category = 'valuable',
        weight = 100,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        category = 'valuable',
        weight = 2500,
        description = 'Smelted from gold ore and a silver bar.',
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        category = 'valuable',
        weight = 100,
    },

    ['10kgoldchain'] = {
        label = '10k Gold Chain',
        category = 'valuable',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        category = 'drug',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        category = 'drug',
        weight = 100,
        client = { image = 'cocaine_baggy.png' },
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        category = 'drug',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        category = 'drug',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        category = 'drug',
        weight = 100,
        client = { image = 'xtc_baggy.png' },
    },

    ['meth'] = {
        label = 'Methamphetamine',
        category = 'drug',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        category = 'drug',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_white-widow'] = {
        label = 'OGKush 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        category = 'drug',
        weight = 200,
        client = { image = 'weed.png' },
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        category = 'drug',
        weight = 1,
        client = { image = 'weed_seed.png' },
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        category = 'drug',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        category = 'drug',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        category = 'drug',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        category = 'drug',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        category = 'drug',
        weight = 0,
        client = { image = 'weed_baggy_empty.png' },
    },

    ['firstaid'] = {
        label = 'First Aid',
        category = 'medical',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        category = 'medical',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Painkillers',
        category = 'medical',
        weight = 400,
    },

    ['firework1'] = {
        label = '2Brothers',
        category = 'misc',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        category = 'misc',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        category = 'misc',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        category = 'misc',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel Ingot',
        category = 'material',
        weight = 3000,
        description = 'Made from iron ingots and coal at a smelter (city_mining).',
    },

    ['rubber'] = {
        label = 'Rubber',
        category = 'material',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        category = 'material',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron Ingot',
        category = 'material',
        weight = 2000,
        description = 'Smelted from iron ore.',
    },

    ['copper'] = {
        label = 'Copper Ingot',
        category = 'material',
        weight = 2000,
        description = 'Smelted from copper ore.',
    },

    ['aluminum'] = {
        label = 'Aluminium',
        category = 'material',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        category = 'material',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        category = 'material',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        category = 'tool',
        weight = 1000,
        client = { image = 'usb_black.png' },
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        category = 'electronics',
        weight = 100,
    },

    ['darkchat_usb'] = {
        label = 'Encrypted USB',
        category = 'electronics',
        weight = 50,
        description = 'Opens DarkChat on your phone while you carry it',
        client = { image = 'usb_black.png' },
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        category = 'electronics',
        weight = 100,
        client = { image = 'usb_device.png' },
    },

    ['toaster'] = {
        label = 'Toaster',
        category = 'electronics',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        category = 'electronics',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        category = 'tool',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        category = 'tool',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        category = 'tool',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        category = 'tool',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        category = 'tool',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        category = 'tool',
        weight = 3000,
        client = { image = 'diving_tube.png' },
    },

    ['antipatharia_coral'] = {
        label = 'Antipatharia',
        category = 'valuable',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Dendrogyra',
        category = 'valuable',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        category = 'tool',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        category = 'tool',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        category = 'drink',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        category = 'food',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        category = 'drink',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        category = 'drink',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        category = 'drink',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        category = 'drink',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        category = 'drink',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        category = 'food',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        category = 'misc',
        weight = 1000,
        client = { image = 'walkstick.png' },
    },

    ['lighter'] = {
        label = 'Lighter',
        category = 'tool',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        category = 'tool',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        category = 'misc',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        category = 'misc',
        weight = 200,
        client = { image = 'evidence.png' },
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        category = 'misc',
        weight = 200,
        client = { image = 'evidence.png' },
    },

    ['harness'] = {
        label = 'Harness',
        category = 'tool',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        category = 'tool',
        weight = 200,
    },

    -- Prison contraband (city_prison): parts found in hidden spots, combined into the three below
    ['prison_scrap'] = {
        label = 'Scrap Metal',
        category = 'material',
        weight = 150,
        description = 'A sharp piece of metal from somewhere it should not be',
        client = { image = 'scrapmetal.png' },
    },

    ['prison_cloth'] = {
        label = 'Cloth Strip',
        category = 'material',
        weight = 50,
        description = 'Torn from a prison uniform',
        client = { image = 'rubber.png' },
    },

    ['prison_wire'] = {
        label = 'Copper Wire',
        category = 'material',
        weight = 80,
        client = { image = 'copper.png' },
    },

    ['prison_battery'] = {
        label = 'Small Battery',
        category = 'electronics',
        weight = 60,
        client = { image = 'lighter.png' },
    },

    ['prison_circuit'] = {
        label = 'Circuit Board',
        category = 'electronics',
        weight = 80,
        client = { image = 'tunerchip.png' },
    },

    ['prison_jammer'] = {
        label = 'Improvised Jammer',
        category = 'electronics',
        weight = 300,
        description = 'Opens a prison gate terminal, if your hands are steady',
        client = { image = 'radiojammer.png' },
    },

    ['burner_phone'] = {
        label = 'Burner Phone',
        category = 'electronics',
        weight = 150,
        stack = false,
        consume = 0,
        description = 'Unknown number. Contacts and messages only.',
        client = { image = 'samsungphone.png' },
    },

    -- Fishing (city_fishing): licence, rods, bait, tackle, crab pots, the catch and what comes up with it
    ['fishing_license'] = {
        label = 'Fishing Licence',
        category = 'document',
        weight = 10,
        stack = false,
        description = 'Lets you sell fish at the market. Bought at the fishing shop.',
        client = { image = 'driver_license.png' },
    },

    ['fishing_rod_starter'] = {
        label = 'Starter Rod',
        category = 'tool',
        weight = 1200,
        stack = false,
        description = 'A simple rod. Use it to start fishing.',
        client = { image = 'fishingrod.png' },
    },

    ['fishing_rod_fiberglass'] = {
        label = 'Fiberglass Rod',
        category = 'tool',
        weight = 1300,
        stack = false,
        description = 'Takes bait. Use it to start fishing.',
        client = { image = 'fishingrod.png' },
    },

    ['fishing_rod_carbon'] = {
        label = 'Carbon Rod',
        category = 'tool',
        weight = 1100,
        stack = false,
        description = 'Takes bait and one tackle. Use it to start fishing.',
        client = { image = 'fishingrod.png' },
    },

    ['fishing_rod_pro'] = {
        label = 'Pro Rod',
        category = 'tool',
        weight = 1000,
        stack = false,
        description = 'Takes bait and two tackles. Use it to start fishing.',
        client = { image = 'fishingrod.png' },
    },

    ['bait_worm'] = {
        label = 'Worms',
        category = 'tool',
        weight = 10,
        description = 'Fish bite sooner. Use it to put it on your rods.',
        client = { image = 'fishbait.png' },
    },

    ['bait_deluxe'] = {
        label = 'Deluxe Bait',
        category = 'tool',
        weight = 15,
        description = 'Fish bite much sooner and the catch bar is bigger. Use it to put it on your rods.',
        client = { image = 'fishbait.png' },
    },

    ['bait_magnet'] = {
        label = 'Magnet Bait',
        category = 'tool',
        weight = 30,
        description = 'More treasure. Use it to put it on your rods.',
        client = { image = 'fishbait.png' },
    },

    ['bait_wild'] = {
        label = 'Wild Bait',
        category = 'tool',
        weight = 15,
        description = 'Sometimes two fish bite at once. Use it to put it on your rods.',
        client = { image = 'fishbait.png' },
    },

    ['bait_challenge'] = {
        label = 'Challenge Bait',
        category = 'tool',
        weight = 15,
        description = 'A perfect catch gives three fish; three escapes lose it. Use it to put it on your rods.',
        client = { image = 'fishbait.png' },
    },

    ['tackle_spinner'] = {
        label = 'Spinner',
        category = 'tool',
        weight = 40,
        description = 'Fish bite sooner. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_trap'] = {
        label = 'Trap Bobber',
        category = 'tool',
        weight = 40,
        description = 'The catch meter drops slower. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_lead'] = {
        label = 'Lead Bobber',
        category = 'tool',
        weight = 40,
        description = 'The catch bar stops bouncing. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_sonar'] = {
        label = 'Sonar Bobber',
        category = 'tool',
        weight = 40,
        description = 'Shows which fish took the bait. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_cork'] = {
        label = 'Cork Bobber',
        category = 'tool',
        weight = 40,
        description = 'A bigger catch bar. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_treasure'] = {
        label = 'Treasure Hook',
        category = 'tool',
        weight = 40,
        description = 'More treasure chests. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_barbed'] = {
        label = 'Barbed Hook',
        category = 'tool',
        weight = 40,
        description = 'The catch bar sticks to the fish. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_quality'] = {
        label = 'Quality Bobber',
        category = 'tool',
        weight = 40,
        description = 'Better fish. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['tackle_curiosity'] = {
        label = 'Curiosity Lure',
        category = 'tool',
        weight = 40,
        description = 'Rare fish bite more often. Use it to fit it on a rod with a free slot (20 bites).',
    },

    ['crab_pot'] = {
        label = 'Crab Pot',
        category = 'tool',
        weight = 3000,
        description = 'Use it at the water with bait in your pockets.',
    },

    ['fish_anchovy'] = {
        label = 'Anchovy',
        category = 'food',
        weight = 30,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_sardine'] = {
        label = 'Sardine',
        category = 'food',
        weight = 60,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_mackerel'] = {
        label = 'Mackerel',
        category = 'food',
        weight = 500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_seabass'] = {
        label = 'Sea Bass',
        category = 'food',
        weight = 2500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_rockfish'] = {
        label = 'Rockfish',
        category = 'food',
        weight = 1500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_red_snapper'] = {
        label = 'Red Snapper',
        category = 'food',
        weight = 3000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_halibut'] = {
        label = 'Halibut',
        category = 'food',
        weight = 6000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_yellowtail'] = {
        label = 'Yellowtail',
        category = 'food',
        weight = 6000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_squid'] = {
        label = 'Squid',
        category = 'food',
        weight = 800,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_octopus'] = {
        label = 'Octopus',
        category = 'food',
        weight = 4000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_leopard_shark'] = {
        label = 'Leopard Shark',
        category = 'food',
        weight = 12000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_bluefin_tuna'] = {
        label = 'Bluefin Tuna',
        category = 'food',
        weight = 40000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_mahi_mahi'] = {
        label = 'Mahi-Mahi',
        category = 'food',
        weight = 10000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_swordfish'] = {
        label = 'Swordfish',
        category = 'food',
        weight = 45000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_blue_marlin'] = {
        label = 'Blue Marlin',
        category = 'food',
        weight = 60000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_mako_shark'] = {
        label = 'Mako Shark',
        category = 'food',
        weight = 50000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_tilapia'] = {
        label = 'Tilapia',
        category = 'food',
        weight = 800,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_mullet'] = {
        label = 'Mullet',
        category = 'food',
        weight = 1200,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_pupfish'] = {
        label = 'Desert Pupfish',
        category = 'food',
        weight = 5,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_rainbow_trout'] = {
        label = 'Rainbow Trout',
        category = 'food',
        weight = 1500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_steelhead'] = {
        label = 'Steelhead',
        category = 'food',
        weight = 4000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_chinook_salmon'] = {
        label = 'Chinook Salmon',
        category = 'food',
        weight = 9000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_smallmouth_bass'] = {
        label = 'Smallmouth Bass',
        category = 'food',
        weight = 1200,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_sturgeon'] = {
        label = 'White Sturgeon',
        category = 'food',
        weight = 30000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_largemouth_bass'] = {
        label = 'Largemouth Bass',
        category = 'food',
        weight = 2000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_bluegill'] = {
        label = 'Bluegill',
        category = 'food',
        weight = 150,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_crappie'] = {
        label = 'Crappie',
        category = 'food',
        weight = 400,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_perch'] = {
        label = 'Yellow Perch',
        category = 'food',
        weight = 300,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_walleye'] = {
        label = 'Walleye',
        category = 'food',
        weight = 2500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_catfish'] = {
        label = 'Channel Catfish',
        category = 'food',
        weight = 5000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_carp'] = {
        label = 'Common Carp',
        category = 'food',
        weight = 4000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_eel'] = {
        label = 'American Eel',
        category = 'food',
        weight = 1500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_bullhead'] = {
        label = 'Brown Bullhead',
        category = 'food',
        weight = 700,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_ghost_sturgeon'] = {
        label = 'Ghost Sturgeon',
        category = 'food',
        weight = 60000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_golden_marlin'] = {
        label = 'Golden Marlin',
        category = 'food',
        weight = 80000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_king_salmon'] = {
        label = 'King of Zancudo',
        category = 'food',
        weight = 15000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_chiliad_rainbow'] = {
        label = 'Chiliad Rainbow',
        category = 'food',
        weight = 6000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_canal_leviathan'] = {
        label = 'Canal Leviathan',
        category = 'food',
        weight = 45000,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['fish_jellyfish'] = {
        label = 'Jellyfish',
        category = 'food',
        weight = 500,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_lobster'] = {
        label = 'Lobster',
        category = 'food',
        weight = 800,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_crab'] = {
        label = 'Dungeness Crab',
        category = 'food',
        weight = 700,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_shrimp'] = {
        label = 'Shrimp',
        category = 'food',
        weight = 30,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_oyster'] = {
        label = 'Oyster',
        category = 'food',
        weight = 100,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_mussel'] = {
        label = 'Mussel',
        category = 'food',
        weight = 40,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_clam'] = {
        label = 'Clam',
        category = 'food',
        weight = 60,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_crayfish'] = {
        label = 'Crayfish',
        category = 'food',
        weight = 60,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['crab_snail'] = {
        label = 'Freshwater Snail',
        category = 'food',
        weight = 20,
        description = 'Sell it at the fish market.',
        client = { image = 'fish.png' },
    },

    ['seaweed'] = {
        label = 'Seaweed',
        category = 'material',
        weight = 100,
        description = 'Sell it at the fish market.',
    },

    ['junk_can'] = {
        label = 'Soda Can',
        category = 'misc',
        weight = 50,
        client = { image = 'trash_can.png' },
    },

    ['junk_boot'] = {
        label = 'Old Boot',
        category = 'misc',
        weight = 800,
        client = { image = 'trash.png' },
    },

    ['junk_tire'] = {
        label = 'Tire',
        category = 'misc',
        weight = 8000,
        client = { image = 'trash.png' },
    },

    ['junk_newspaper'] = {
        label = 'Soggy Newspaper',
        category = 'misc',
        weight = 200,
        client = { image = 'trash.png' },
    },

    ['fishing_pearl'] = {
        label = 'Pearl',
        category = 'valuable',
        weight = 20,
        description = 'Found in a fishing chest.',
    },

    -- Mining (city_mining): licences, tools, safety gear, ore, ingots, geodes, gems, jewellery. Images marked as
    -- placeholders until the real ones are made (list in docs/city-mining.md).
    ['mining_license'] = {
        label = 'Mining Licence',
        category = 'document',
        weight = 10,
        stack = false,
        description = 'Lets you sell ore and use the smelter. Bought at the mining shop.',
        client = { image = 'driver_license.png' },
    },

    ['explosives_license'] = {
        label = 'Explosives Licence',
        category = 'document',
        weight = 10,
        stack = false,
        description = 'Lets you buy dynamite. The police must grant it in the MDT first.',
        client = { image = 'id_card.png' },
    },

    ['pickaxe'] = {
        label = 'Pickaxe',
        category = 'tool',
        weight = 2500,
        stack = false,
        description = 'Breaks tier 1 veins.',
        client = { image = 'weapon_stone_hatchet.png' },
    },

    ['steel_pickaxe'] = {
        label = 'Steel Pickaxe',
        category = 'tool',
        weight = 2800,
        stack = false,
        description = 'Breaks veins up to tier 2.',
        client = { image = 'weapon_stone_hatchet.png' },
    },

    ['hardened_pickaxe'] = {
        label = 'Hardened Pickaxe',
        category = 'tool',
        weight = 3000,
        stack = false,
        description = 'Breaks veins up to tier 3.',
        client = { image = 'weapon_stone_hatchet.png' },
    },

    ['diamond_pickaxe'] = {
        label = 'Diamond Pickaxe',
        category = 'tool',
        weight = 3200,
        stack = false,
        description = 'Breaks every vein.',
        client = { image = 'weapon_stone_hatchet.png' },
    },

    ['gold_pan'] = {
        label = 'Gold Pan',
        category = 'tool',
        weight = 1000,
        stack = false,
        description = 'Pan the gravel spots in the rivers.',
        client = { image = 'scrapmetal.png' },
    },

    ['sluice_box'] = {
        label = 'Sluice Box',
        category = 'tool',
        weight = 8000,
        stack = false,
        description = 'Use it at a river gravel spot and stay close. Needs the Golden Pan skill.',
        client = { image = 'scrapmetal.png' },
    },

    ['mining_helmet'] = {
        label = 'Mining Helmet',
        category = 'tool',
        weight = 800,
        stack = false,
        description = 'Use it to put it on: a lamp, and less harm in a cave-in.',
        client = { image = 'weapon_hammer.png' },
    },

    ['mining_gloves'] = {
        label = 'Mining Gloves',
        category = 'tool',
        weight = 300,
        stack = false,
        description = 'Your tools wear slower while you carry them.',
        client = { image = 'weapon_hammer.png' },
    },

    ['mining_boots'] = {
        label = 'Mining Boots',
        category = 'tool',
        weight = 1200,
        stack = false,
        description = 'You walk faster with a heavy load while you carry them.',
        client = { image = 'weapon_hammer.png' },
    },

    ['home_furnace'] = {
        label = 'Home Furnace',
        category = 'tool',
        weight = 30000,
        stack = false,
        description = 'Use it inside your property to install it. Slow, small batches, no stamp.',
        client = { image = 'scrapmetal.png' },
    },

    ['dynamite'] = {
        label = 'Dynamite',
        category = 'tool',
        weight = 500,
        description = 'Registered dynamite. Breaks boulders and rockfalls.',
        client = { image = 'weapon_stickybomb.png' },
    },

    ['homemade_dynamite'] = {
        label = 'Homemade Dynamite',
        category = 'tool',
        weight = 500,
        description = 'Unstable and unregistered.',
        client = { image = 'weapon_pipebomb.png' },
    },

    ['gunpowder'] = {
        label = 'Gunpowder',
        category = 'material',
        weight = 250,
        client = { image = 'scrapmetal.png' },
    },

    ['copper_ore'] = { label = 'Copper Ore', category = 'material', weight = 1000, client = { image = 'copper.png' } },
    ['iron_ore'] = { label = 'Iron Ore', category = 'material', weight = 1000, client = { image = 'iron.png' } },
    ['coal'] = { label = 'Coal', category = 'material', weight = 500, client = { image = 'scrapmetal.png' } },
    ['silver_ore'] = { label = 'Silver Ore', category = 'material', weight = 1000, client = { image = 'steel.png' } },
    ['quartz'] = { label = 'Quartz', category = 'material', weight = 500, client = { image = 'steel.png' } },
    ['saltpeter'] = { label = 'Saltpeter', category = 'material', weight = 500, client = { image = 'scrapmetal.png' } },
    ['gold_ore'] = { label = 'Gold Ore', category = 'material', weight = 1000, client = { image = 'goldbar.png' } },
    ['platinum_ore'] = { label = 'Platinum Ore', category = 'material', weight = 1000, client = { image = 'steel.png' } },
    ['gold_nugget'] = { label = 'Gold Nugget', category = 'valuable', weight = 50, client = { image = 'goldbar.png' } },

    ['silver_bar'] = {
        label = 'Silver Bar',
        category = 'valuable',
        weight = 2000,
        description = 'Smelted from silver ore.',
        client = { image = 'steel.png' },
    },

    ['platinum_bar'] = {
        label = 'Platinum Bar',
        category = 'valuable',
        weight = 2500,
        description = 'Smelted from platinum ore and a gold bar.',
        client = { image = 'steel.png' },
    },

    ['geode'] = { label = 'Geode', category = 'misc', weight = 1500, description = 'Open it at Vangelico.', client = { image = 'scrapmetal.png' } },
    ['deep_geode'] = { label = 'Deep Geode', category = 'misc', weight = 2000, description = 'Open it at Vangelico.', client = { image = 'scrapmetal.png' } },
    ['ancient_geode'] = { label = 'Ancient Geode', category = 'misc', weight = 2500, description = 'Open it at Vangelico.', client = { image = 'scrapmetal.png' } },

    ['rough_amethyst'] = { label = 'Rough Amethyst', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['rough_topaz'] = { label = 'Rough Topaz', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['rough_emerald'] = { label = 'Rough Emerald', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['rough_ruby'] = { label = 'Rough Ruby', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['rough_diamond'] = { label = 'Rough Diamond', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['amethyst'] = { label = 'Amethyst', category = 'valuable', weight = 50, client = { image = 'diamond_ring.png' } },
    ['topaz'] = { label = 'Topaz', category = 'valuable', weight = 50, client = { image = 'diamond_ring.png' } },
    ['emerald'] = { label = 'Emerald', category = 'valuable', weight = 50, client = { image = 'diamond_ring.png' } },
    ['ruby'] = { label = 'Ruby', category = 'valuable', weight = 50, client = { image = 'diamond_ring.png' } },
    ['gem_dust'] = { label = 'Gem Dust', category = 'misc', weight = 50, description = 'What is left of a gem that broke.', client = { image = 'scrapmetal.png' } },

    ['silver_ring'] = { label = 'Silver Ring', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['emerald_necklace'] = { label = 'Emerald Necklace', category = 'valuable', weight = 100, client = { image = 'goldchain.png' } },
    ['ruby_ring'] = { label = 'Ruby Ring', category = 'valuable', weight = 100, client = { image = 'diamond_ring.png' } },
    ['platinum_watch'] = { label = 'Platinum Watch', category = 'valuable', weight = 100, client = { image = 'rolex.png' } },

    ['ancient_coin'] = { label = 'Ancient Coin', category = 'valuable', weight = 300, client = { image = 'goldbar.png' } },
    ['old_relic'] = { label = 'Old Relic', category = 'valuable', weight = 300, client = { image = 'goldchain.png' } },
    ['fossil'] = { label = 'Fossil', category = 'valuable', weight = 300, client = { image = 'scrapmetal.png' } },
    ['mountain_heart'] = {
        label = 'Heart of the Mountain',
        category = 'valuable',
        weight = 1000,
        description = 'One of a kind. Only ancient geodes hold it.',
        client = { image = 'diamond_ring.png' },
    },
}
