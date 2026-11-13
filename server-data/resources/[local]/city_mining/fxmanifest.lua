fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_mining'
description 'Mining: licence, pickaxes, veins in four tiers across the map, a strike minigame, smelting with stamped ingots, geodes and gem cutting at Vangelico, panning, dynamite, levels with a skill tree and a tablet app'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/veins.lua',
    'client/smelter.lua',
    'client/jeweler.lua',
    'client/effects.lua',
    'client/staff.lua',
    'client/app.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/mine.lua',
    'server/panning.lua',
    'server/market.lua',
    'server/shop.lua',
    'server/smelter.lua',
    'server/furnace.lua',
    'server/jeweler.lua',
    'server/dynamite.lua',
    'server/crime.lua',
    'server/staff.lua',
    'server/app.lua',
}

-- The minigames; the tablet app (web/app/) runs inside city_os
ui_page 'web/index.html'

files {
    'shared/*.lua',
    'client/places.lua',
    'client/actions.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/minigame.js',
    'web/app/index.html',
    'web/app/app.css',
    'web/app/js/*.js',
}

dependencies {
    'city_os',
    'city_ui',
    'city_inventory',
    'city_economy',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'city_points',
    'qbx_core',
}
