fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_militech'
description 'Militech Tuning: a Forza-style handling tuner used from the driver seat, saved on owned cars'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'shared/tuning.lua',
    'client/handling.lua',
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
}
