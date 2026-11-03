fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_inventory'
description 'Player inventory for fivem-city (replaces ox_inventory)'
version '0.1.0'

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
    'server/exports.lua',
    'server/commands.lua',
}

files {
    'data/*.lua',
    'shared/*.lua',
    'locales/*.json',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
