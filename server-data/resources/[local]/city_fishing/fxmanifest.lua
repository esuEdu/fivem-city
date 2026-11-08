fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_fishing'
description 'Fishing: licence, rods, bait and tackle, a catch minigame, levels and a skill tree, fish market, crab pots, boat rental, frenzies, tournaments and a tablet app'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/fishing.lua',
    'client/pots.lua',
    'client/events.lua',
    'client/app.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/sessions.lua',
    'server/shop.lua',
    'server/market.lua',
    'server/pots.lua',
    'server/boat.lua',
    'server/events.lua',
    'server/app.lua',
}

-- The minigame and power bar; the tablet app (web/app/) runs inside city_os
ui_page 'web/index.html'

files {
    'shared/*.lua',
    'client/water.lua',
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
    'qbx_core',
}
