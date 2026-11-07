fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_notes'
description 'Notes app for city_phone: notes saved per character, pinned notes first, search'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'web/index.html',
    'web/icon.svg',
    'web/style.css',
    'web/js/*.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'city_phone',
}
