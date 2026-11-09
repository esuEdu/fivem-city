fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_militech_staff'
description 'Staff Militech: a staff-only tuner that sets every handling field of a car to any value'
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
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'shared/fields.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'oxmysql',
    'city_ui',
    'city_inventory',
    'city_militech',
}
