fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_calls'
description 'Phone app for city_phone: calls (up to 4 people), contacts, favorites, recents, blocked numbers and sharing your contact'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/call.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/contacts.lua',
    'server/share.lua',
    'server/emergency.lua',
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
    'pma-voice',
}
