fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_dealership'
description 'Premium Deluxe Motorsport: a computer with the car catalogue (photos, stats, filters), test drives, buying in full or financed'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qbx_core/modules/lib.lua',
    'server/main.lua',
    'server/testdrive.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'client/testdrive.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'city_points',
    'city_ui',
    'city_economy',
    'city_bank',
    'city_garages',
}
