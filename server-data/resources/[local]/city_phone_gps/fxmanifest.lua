fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_gps'
description 'Maps app for city_phone: opens the game map (route, your position) and shows the route you have set'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'web/index.html',
    'web/icon.svg',
    'web/style.css',
    'web/main.js',
    'web/locales/*.json',
}

dependencies {
    'ox_lib',
    'city_phone',
}
