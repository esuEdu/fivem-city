-- What can bite, per region. Server only, so players can't read chances, hours or the legendary spots.
-- price: dollars at 1 star. difficulty: 15-110, how hard the minigame is. behavior: mixed/smooth/sinker/floater/dart.
-- size: cm. regions: where it lives. hours: game-hour windows { from, to } (to is exclusive, may wrap past midnight).
-- weather: nil (any), 'clear', 'rain', 'storm' or 'fog'. chance: base chance once the entry is reached. depth: shore
-- distance (0-5) under which the chance drops by depthMult per band missing. minLevel: fishing level needed.
-- precedence: entries are tried lowest first (ties shuffled); junk is last. kind: 'fish' (minigame) or 'item' (no
-- minigame). legendary: only at its spot, with the legendary chance instead of `chance`.

local ALL_DAY = { { 0, 24 } }
local DAY = { { 6, 19 } }
local NIGHT = { { 18, 2 } }

local fish = {
    -- Ocean, near the coast
    { name = 'fish_anchovy', label = 'Anchovy', price = 25, difficulty = 30, behavior = 'dart', size = { 8, 20 }, regions = { 'ocean' }, hours = ALL_DAY, chance = 0.5, depth = 2 },
    { name = 'fish_sardine', label = 'Sardine', price = 20, difficulty = 30, behavior = 'dart', size = { 10, 25 }, regions = { 'ocean' }, hours = DAY, chance = 0.55, depth = 2 },
    { name = 'fish_mackerel', label = 'Mackerel', price = 35, difficulty = 40, behavior = 'dart', size = { 20, 45 }, regions = { 'ocean', 'deep' }, hours = ALL_DAY, chance = 0.45, depth = 3 },
    { name = 'fish_seabass', label = 'Sea Bass', price = 60, difficulty = 45, behavior = 'mixed', size = { 30, 75 }, regions = { 'ocean' }, hours = ALL_DAY, chance = 0.35, depth = 3 },
    { name = 'fish_rockfish', label = 'Rockfish', price = 50, difficulty = 40, behavior = 'sinker', size = { 20, 55 }, regions = { 'ocean' }, hours = { { 18, 6 } }, chance = 0.4, depth = 3 },
    { name = 'fish_red_snapper', label = 'Red Snapper', price = 70, difficulty = 45, behavior = 'mixed', size = { 30, 80 }, regions = { 'ocean' }, hours = DAY, weather = 'rain', chance = 0.45, depth = 3 },
    { name = 'fish_halibut', label = 'Halibut', price = 85, difficulty = 50, behavior = 'sinker', size = { 40, 120 }, regions = { 'ocean' }, hours = { { 6, 11 }, { 19, 2 } }, chance = 0.3, depth = 4 },
    { name = 'fish_yellowtail', label = 'Yellowtail', price = 110, difficulty = 60, behavior = 'mixed', size = { 50, 120 }, regions = { 'ocean', 'deep' }, hours = DAY, chance = 0.25, depth = 4 },
    { name = 'fish_squid', label = 'Squid', price = 90, difficulty = 75, behavior = 'sinker', size = { 20, 60 }, regions = { 'ocean', 'deep' }, hours = NIGHT, chance = 0.3, depth = 4 },
    { name = 'fish_octopus', label = 'Octopus', price = 160, difficulty = 90, behavior = 'sinker', size = { 30, 120 }, regions = { 'ocean' }, hours = { { 6, 13 } }, chance = 0.15, depth = 5, minLevel = 8 },
    { name = 'fish_leopard_shark', label = 'Leopard Shark', price = 140, difficulty = 70, behavior = 'smooth', size = { 80, 180 }, regions = { 'ocean' }, hours = ALL_DAY, chance = 0.12, depth = 4, minLevel = 6 },

    -- Deep sea (a boat, outside the coast outline)
    { name = 'fish_bluefin_tuna', label = 'Bluefin Tuna', price = 220, difficulty = 75, behavior = 'smooth', size = { 100, 300 }, regions = { 'deep' }, hours = DAY, chance = 0.3, depth = 5, minLevel = 6 },
    { name = 'fish_mahi_mahi', label = 'Mahi-Mahi', price = 160, difficulty = 65, behavior = 'dart', size = { 60, 150 }, regions = { 'deep' }, hours = DAY, weather = 'clear', chance = 0.35, depth = 5, minLevel = 4 },
    { name = 'fish_swordfish', label = 'Swordfish', price = 300, difficulty = 85, behavior = 'mixed', size = { 120, 300 }, regions = { 'deep' }, hours = { { 18, 6 } }, chance = 0.2, depth = 5, minLevel = 10 },
    { name = 'fish_blue_marlin', label = 'Blue Marlin', price = 450, difficulty = 95, behavior = 'dart', size = { 150, 400 }, regions = { 'deep' }, hours = ALL_DAY, chance = 0.12, depth = 5, minLevel = 15 },
    { name = 'fish_mako_shark', label = 'Mako Shark', price = 380, difficulty = 90, behavior = 'mixed', size = { 150, 350 }, regions = { 'deep' }, hours = ALL_DAY, chance = 0.15, depth = 5, minLevel = 12 },

    -- Alamo Sea (salt lake)
    { name = 'fish_tilapia', label = 'Tilapia', price = 30, difficulty = 30, behavior = 'mixed', size = { 20, 50 }, regions = { 'alamo' }, hours = DAY, chance = 0.5, depth = 2 },
    { name = 'fish_mullet', label = 'Mullet', price = 40, difficulty = 35, behavior = 'dart', size = { 25, 60 }, regions = { 'alamo' }, hours = ALL_DAY, chance = 0.45, depth = 2 },
    { name = 'fish_pupfish', label = 'Desert Pupfish', price = 120, difficulty = 70, behavior = 'dart', size = { 3, 7 }, regions = { 'alamo' }, hours = { { 6, 20 } }, weather = 'clear', chance = 0.2, depth = 1, minLevel = 5 },

    -- Rivers
    { name = 'fish_rainbow_trout', label = 'Rainbow Trout', price = 65, difficulty = 45, behavior = 'mixed', size = { 25, 65 }, regions = { 'river', 'lake' }, hours = DAY, weather = 'clear', chance = 0.4, depth = 2 },
    { name = 'fish_steelhead', label = 'Steelhead', price = 90, difficulty = 60, behavior = 'dart', size = { 50, 100 }, regions = { 'river' }, hours = ALL_DAY, weather = 'rain', chance = 0.35, depth = 2, minLevel = 4 },
    { name = 'fish_chinook_salmon', label = 'Chinook Salmon', price = 120, difficulty = 55, behavior = 'mixed', size = { 60, 130 }, regions = { 'river' }, hours = DAY, chance = 0.3, depth = 3, minLevel = 3 },
    { name = 'fish_smallmouth_bass', label = 'Smallmouth Bass', price = 50, difficulty = 28, behavior = 'mixed', size = { 25, 55 }, regions = { 'river', 'lake' }, hours = ALL_DAY, chance = 0.45, depth = 1 },
    { name = 'fish_sturgeon', label = 'White Sturgeon', price = 200, difficulty = 80, behavior = 'mixed', size = { 100, 250 }, regions = { 'river', 'alamo' }, hours = DAY, chance = 0.12, depth = 3, minLevel = 10 },

    -- Lakes
    { name = 'fish_largemouth_bass', label = 'Largemouth Bass', price = 70, difficulty = 50, behavior = 'mixed', size = { 25, 70 }, regions = { 'lake' }, hours = DAY, chance = 0.4, depth = 2 },
    { name = 'fish_bluegill', label = 'Bluegill', price = 15, difficulty = 15, behavior = 'mixed', size = { 8, 20 }, regions = { 'lake' }, hours = ALL_DAY, chance = 0.6, depth = 0 },
    { name = 'fish_crappie', label = 'Crappie', price = 30, difficulty = 30, behavior = 'dart', size = { 15, 35 }, regions = { 'lake' }, hours = ALL_DAY, chance = 0.5, depth = 1 },
    { name = 'fish_perch', label = 'Yellow Perch', price = 35, difficulty = 35, behavior = 'dart', size = { 15, 35 }, regions = { 'lake', 'river' }, hours = ALL_DAY, chance = 0.45, depth = 1 },
    { name = 'fish_walleye', label = 'Walleye', price = 90, difficulty = 45, behavior = 'smooth', size = { 30, 80 }, regions = { 'lake' }, hours = { { 12, 2 } }, weather = 'rain', chance = 0.4, depth = 3 },
    { name = 'fish_catfish', label = 'Channel Catfish', price = 140, difficulty = 75, behavior = 'mixed', size = { 40, 120 }, regions = { 'lake', 'river', 'alamo' }, hours = { { 6, 24 } }, weather = 'rain', chance = 0.35, depth = 2, minLevel = 4 },
    { name = 'fish_carp', label = 'Common Carp', price = 20, difficulty = 15, behavior = 'mixed', size = { 30, 90 }, regions = { 'lake', 'alamo', 'canal' }, hours = ALL_DAY, chance = 0.5, depth = 0, precedence = 5 },

    -- LS River canal
    { name = 'fish_eel', label = 'American Eel', price = 85, difficulty = 70, behavior = 'smooth', size = { 40, 120 }, regions = { 'canal', 'ocean' }, hours = { { 16, 2 } }, weather = 'rain', chance = 0.3, depth = 1 },
    { name = 'fish_bullhead', label = 'Brown Bullhead', price = 45, difficulty = 46, behavior = 'smooth', size = { 20, 45 }, regions = { 'canal', 'lake' }, hours = ALL_DAY, chance = 0.45, depth = 0 },

    -- Legendaries: one spot each (server/regions.lua spots), extremely rare
    { name = 'fish_ghost_sturgeon', label = 'Ghost Sturgeon', price = 8000, difficulty = 105, behavior = 'mixed', size = { 180, 300 }, regions = { 'alamo' }, hours = { { 3, 5 } }, weather = 'fog', legendary = 'ghost_sturgeon', precedence = -100 },
    { name = 'fish_golden_marlin', label = 'Golden Marlin', price = 15000, difficulty = 110, behavior = 'dart', size = { 250, 450 }, regions = { 'deep' }, hours = { { 21, 4 } }, weather = 'storm', legendary = 'golden_marlin', precedence = -100 },
    { name = 'fish_king_salmon', label = 'King of Zancudo', price = 6000, difficulty = 95, behavior = 'mixed', size = { 100, 160 }, regions = { 'river' }, hours = { { 5, 8 } }, weather = 'rain', legendary = 'king_salmon', precedence = -100 },
    { name = 'fish_chiliad_rainbow', label = 'Chiliad Rainbow', price = 5000, difficulty = 90, behavior = 'dart', size = { 70, 110 }, regions = { 'river' }, hours = { { 6, 8 } }, weather = 'clear', legendary = 'chiliad_rainbow', precedence = -100 },
    { name = 'fish_canal_leviathan', label = 'Canal Leviathan', price = 7000, difficulty = 100, behavior = 'sinker', size = { 150, 250 }, regions = { 'canal' }, hours = { { 0, 3 } }, weather = 'rain', legendary = 'canal_leviathan', precedence = -100 },

    -- Not fish: no minigame, 3 XP
    { name = 'fish_jellyfish', label = 'Jellyfish', kind = 'item', price = 40, regions = { 'ocean', 'deep' }, hours = NIGHT, chance = 0.05, precedence = 50 },
    { name = 'seaweed', label = 'Seaweed', kind = 'item', price = 5, regions = { 'ocean', 'deep', 'alamo' }, hours = ALL_DAY, chance = 0.2, precedence = 900 },
    { name = 'junk_can', label = 'Soda Can', kind = 'item', junk = true, regions = { 'ocean', 'alamo', 'river', 'lake', 'canal' }, hours = ALL_DAY, chance = 1, precedence = 1000 },
    { name = 'junk_boot', label = 'Old Boot', kind = 'item', junk = true, regions = { 'ocean', 'alamo', 'river', 'lake', 'canal' }, hours = ALL_DAY, chance = 1, precedence = 1000 },
    { name = 'junk_tire', label = 'Tire', kind = 'item', junk = true, regions = { 'ocean', 'alamo', 'lake', 'canal' }, hours = ALL_DAY, chance = 1, precedence = 1000 },
    { name = 'junk_newspaper', label = 'Soggy Newspaper', kind = 'item', junk = true, regions = { 'ocean', 'deep', 'river', 'lake', 'canal' }, hours = ALL_DAY, chance = 1, precedence = 1000 },
}

-- Crab pot catch, tried in order (research section 11)
local crustaceans = {
    salt = {
        { name = 'crab_lobster', label = 'Lobster', price = 120, chance = 0.05 },
        { name = 'crab_crab', label = 'Dungeness Crab', price = 60, chance = 0.1 },
        { name = 'crab_shrimp', label = 'Shrimp', price = 30, chance = 0.2 },
        { name = 'crab_oyster', label = 'Oyster', price = 50, chance = 0.15 },
        { name = 'crab_mussel', label = 'Mussel', price = 20, chance = 0.25 },
        { name = 'crab_clam', label = 'Clam', price = 25, chance = 0.3 },
    },
    fresh = {
        { name = 'crab_crayfish', label = 'Crayfish', price = 40, chance = 0.35 },
        { name = 'crab_snail', label = 'Freshwater Snail', price = 15, chance = 0.55 },
    },
}

local byName = {}

for _, entry in ipairs(fish) do
    entry.kind = entry.kind or 'fish'
    entry.precedence = entry.precedence or 0
    entry.minLevel = entry.minLevel or 0
    entry.depth = entry.depth or 0
    entry.depthMult = entry.depthMult or 0.1
    entry.regionSet = {}
    for _, region in ipairs(entry.regions) do entry.regionSet[region] = true end
    byName[entry.name] = entry
end

for _, list in pairs(crustaceans) do
    for _, entry in ipairs(list) do
        entry.kind = 'crustacean'
        byName[entry.name] = entry
    end
end

return {
    list = fish,
    crustaceans = crustaceans,
    byName = byName,
}
