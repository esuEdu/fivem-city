fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_weather'
description 'Weather app for city_phone: the weather now and the coming changes from Renewed-Weathersync'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
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
    'city_phone',
}
