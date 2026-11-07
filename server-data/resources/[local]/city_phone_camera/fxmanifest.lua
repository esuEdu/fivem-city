fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_camera'
description 'Camera app for city_phone: back camera with zoom, selfie, filters and a clean HUD; photos are saved by city_phone_photos'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'web/overlay.html'

files {
    'client/camera.lua',
    'web/overlay.html',
    'web/overlay.css',
    'web/index.html',
    'web/app.css',
    'web/icon.svg',
    'web/js/*.js',
}

dependencies {
    'ox_lib',
    'city_inventory',
    'city_phone',
    'city_phone_photos',
}
