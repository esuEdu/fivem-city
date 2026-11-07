fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_messages'
description 'Messages app for city_phone: chats and groups, delivered/read, reactions, fixed and live location'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/live.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'shared/texts.lua',
    'web/index.html',
    'web/icon.svg',
    'web/style.css',
    'web/js/*.js',
    'web/locales/*.json',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'city_inventory',
    'city_phone',
}
