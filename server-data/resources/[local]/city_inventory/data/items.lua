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
        weight = 1500,
    },

    ['diamond_ring'] = {
        label = 'Diamond Ring',
        category = 'valuable',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        category = 'valuable',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        category = 'valuable',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        category = 'valuable',
        weight = 1500,
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
        label = 'Steel',
        category = 'material',
        weight = 100,
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
        label = 'Iron',
        category = 'material',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        category = 'material',
        weight = 100,
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
}
