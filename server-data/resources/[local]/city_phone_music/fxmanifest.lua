fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_music'
description 'Music app for city_phone: YouTube or audio links, search by title, library and playlists, shuffle and repeat, only the owner hears it'
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
    'server/library.lua',
    'server/youtube.lua',
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
    'city_phone',
}
