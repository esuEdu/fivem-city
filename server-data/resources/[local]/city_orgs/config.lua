Config = {}

-- Grades every faction shares; the Leader (isboss) runs management, goals and money withdrawals in the app
Config.Grades = {
    [0] = { name = 'Member' },
    [1] = { name = 'Manager' },
    [2] = { name = 'Leader', isboss = true, bankAuth = true },
}

-- Seconds a player has to answer a faction offer on their screen
Config.OfferSeconds = 30

-- Vault stash size, unless a faction entry sets its own `stash = { slots, maxWeight }`
Config.Stash = { slots = 50, maxWeight = 500000 }

-- One tablet app per faction, all sharing one page. The key under `factions` is the qbx gang name (the gangs are
-- created at start and staff puts players in them from the Staff app); the app each member sees is 'org_<gang>'
-- named after their faction. `farmItems` are the city_inventory items the leader can set farm goals for; when new
-- farm items exist, staff adds them here. `vault` is where the faction's stash sits (placeholder spots: move each
-- one to the faction's real QG).
Config.Apps = {
    guns = {
        order = 61,
        color = '#b91f2e',
        icon = {
            glyph = 'M3 9h16l-1.5 4.5h-5.5l-1 4.5h-4l1-4.5h-5zM19 9l2-3M7 9V7',
            colors = { '#5b1118', '#b91f2e', '#2e080c' },
        },
        farmItems = { 'farm_test1', 'farm_test2' },
        factions = {
            arma1 = { label = 'Arma 1', vault = vec4(899.33, -2224.47, 30.56, 357.0) },
            arma2 = { label = 'Arma 2', vault = vec4(189.23, -2461.5, 6.0, 142.0) },
            arma3 = { label = 'Arma 3', vault = vec4(1210.6, -1275.3, 35.2, 90.0) },
        },
    },
}
