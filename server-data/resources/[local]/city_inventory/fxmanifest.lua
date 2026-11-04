fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_inventory'
description 'Player inventory for fivem-city (replaces ox_inventory)'
version '0.7.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/actions.lua',
    'server/exports.lua',
    'server/compat.lua',
    'server/commands.lua',
}

ui_page 'web/index.html'

files {
    'data/*.lua',
    'shared/*.lua',
    'client/weapons.lua',
    'client/use.lua',
    'client/compat.lua',
    'client/craft.lua',
    'client/other.lua',
    'client/shops.lua',
    'client/drops.lua',
    'client/trade.lua',
    'client/vehicles.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'web/images/*.png',
}

dependencies {
    'city_ui',
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
