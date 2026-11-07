fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_dating'
description 'Matchy, the dating app for city_phone: a profile with up to 3 photos, like or pass, matches and a private chat'
version '0.1.0'

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
    'server/profiles.lua',
    'server/deck.lua',
    'server/chat.lua',
}

files {
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
    'city_phone_photos',
}
