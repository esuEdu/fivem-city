fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_news'
description 'Weazel News for city_phone: articles by journalists on duty, breaking news to every phone, likes and comments'
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
    'server/readers.lua',
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
}
