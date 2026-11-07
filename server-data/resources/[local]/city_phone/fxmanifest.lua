fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone'
description 'The fivem-city phone: lock screen, home screen, dynamic island, control center, multitask, settings and the app platform'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/notify.lua',
    'client/flashlight.lua',
    'client/compat.lua',
}

server_scripts {
    'server/main.lua',
    'server/compat.lua',
}

ui_page 'web/index.html'

files {
    'client/apps.lua',
    'client/hold.lua',
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/locales/*.json',
    'web/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'city_ui',
    'city_inventory',
}
