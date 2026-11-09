Config = {}

Config.UseDistance = 2.0

-- Radius of a lab station or an indoor pick spot (they sit on the interior's tables)
Config.StationRadius = 1.5

-- Pick spots: each spot gives its item once, then regrows (server/config.lua). Spots are a grid around `center`
-- (rows x cols, `spacing` metres apart) unless `points` lists them one by one. With a `model` a prop is placed on
-- the ground at each spot; without one the spot is part of the interior (the weed farm's plants). `drug` is the drug
-- it is for; `inside` names the lab whose interior the spots are in.
Config.Fields = {
    weed = {
        label = 'Weed plant',
        drug = 'weed',
        inside = 'weed',
        center = vector3(1051.49, -3196.54, -39.15),
        points = {
            vector3(1045.5, -3192.5, -39.15),
            vector3(1049.5, -3192.5, -39.15),
            vector3(1053.5, -3192.5, -39.15),
            vector3(1057.5, -3192.5, -39.15),
            vector3(1045.5, -3200.5, -39.15),
            vector3(1049.5, -3200.5, -39.15),
            vector3(1053.5, -3200.5, -39.15),
            vector3(1057.5, -3200.5, -39.15),
        },
        item = 'cannabis',
        seconds = 6,
        icon = 'fas fa-cannabis',
        scenario = 'WORLD_HUMAN_GARDENER_PLANT',
    },
    coca = {
        label = 'Coca plant',
        drug = 'coke',
        center = vector3(1905.0, 4920.0, 48.0),
        rows = 3,
        cols = 4,
        spacing = 3.5,
        model = `prop_plant_fern_02a`,
        item = 'coca_leaf',
        seconds = 7,
        icon = 'fas fa-leaf',
        scenario = 'WORLD_HUMAN_GARDENER_PLANT',
    },
    chemicals = {
        label = 'Chemical barrel',
        drug = 'meth',
        center = vector3(1240.0, -3170.0, 5.9),
        rows = 2,
        cols = 4,
        spacing = 4.0,
        model = `prop_barrel_exp_01a`,
        item = 'meth_chemicals',
        seconds = 8,
        icon = 'fas fa-flask',
        anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },
    },
}

-- Labs are the GTA Online biker business interiors (loaded by bob74_ipl), keyed by the drug they make and shared by
-- every gang: a door outside (`entrance`) takes players in, the door inside (`exit`) takes them out. Each recipe is a
-- station inside; inputs and outputs are checked on the server.
Config.Labs = {
    weed = {
        label = 'Weed Farm',
        entrance = vector4(2224.0, 5577.0, 53.8, 0.0),
        exit = vector4(1066.01, -3183.38, -39.16, 93.0),
        recipes = {
            {
                label = 'Dry and bag cannabis',
                coords = vector3(1034.5, -3205.4, -38.2),
                inputs = { cannabis = 4 },
                outputs = { weed_skunk = 2 },
                seconds = 10,
            },
            {
                label = 'Press a weed brick',
                coords = vector3(1039.5, -3203.5, -38.2),
                inputs = { weed_skunk = 10 },
                outputs = { weed_brick = 1 },
                seconds = 15,
            },
        },
    },
    coke = {
        label = 'Cocaine Lockup',
        entrance = vector4(1902.7, 4932.0, 48.9, 0.0),
        exit = vector4(1088.68, -3187.68, -38.99, 176.0),
        recipes = {
            {
                label = 'Process coca leaves',
                coords = vector3(1092.9, -3196.6, -38.99),
                inputs = { coca_leaf = 10 },
                outputs = { coke_small_brick = 1 },
                seconds = 20,
            },
            {
                label = 'Cut and bag a package',
                coords = vector3(1095.4, -3194.9, -38.99),
                inputs = { coke_small_brick = 1 },
                outputs = { cokebaggy = 5 },
                seconds = 10,
            },
            {
                label = 'Press a coke brick',
                coords = vector3(1100.5, -3199.5, -38.99),
                inputs = { coke_small_brick = 2 },
                outputs = { coke_brick = 1 },
                seconds = 15,
            },
        },
    },
    meth = {
        label = 'Meth Lab',
        entrance = vector4(3536.71, 3662.63, 28.12, 172.0),
        exit = vector4(996.92, -3200.83, -36.39, 88.0),
        recipes = {
            {
                label = 'Cook meth',
                coords = vector3(1005.8, -3200.4, -38.52),
                inputs = { meth_chemicals = 2 },
                outputs = { meth = 3 },
                seconds = 25,
            },
        },
    },
}

-- Corner selling: an ox_target option on locals while carrying one of these
Config.CornerItems = { 'weed_skunk', 'cokebaggy', 'meth' }

-- Phone deals: ask this dealer for an order, then deliver it to the buyer at a drop-off
Config.Dealer = {
    coords = vector4(-1172.02, -1571.98, 4.66, 125.0),
    model = `g_m_y_famca_01`,
}

Config.Buyer = { model = `a_m_y_business_02` }

-- The phone notification's sender
Config.DealContact = 'Unknown'

Config.DropOffs = {
    { label = 'Strip Club', coords = vector4(106.24, -1280.32, 29.24, 120.0) },
    { label = 'Vinewood Video', coords = vector4(223.98, 121.53, 102.76, 160.0) },
    { label = 'Taxi depot', coords = vector4(882.67, -160.26, 77.11, 330.0) },
    { label = 'Resort', coords = vector4(-1245.63, 376.21, 75.34, 200.0) },
    { label = 'Bahama Mamas', coords = vector4(-1383.1, -639.99, 28.67, 30.0) },
}
