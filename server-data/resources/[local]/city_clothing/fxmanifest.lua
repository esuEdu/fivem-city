fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_clothing'
description 'Clothing stores and barbers with pictures of every piece, a bag, saved looks and the staff photo tool (replaces illenium-appearance shops)'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/photos.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/photos.lua',
}

ui_page 'web/index.html'

files {
    'client/look.lua',
    'client/camera.lua',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'images/index.json',
    'images/*.webp',
}

dependencies {
    'city_ui',
    'illenium-appearance',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'qbx_core',
}
