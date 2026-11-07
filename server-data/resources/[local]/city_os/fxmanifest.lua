fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_os'
description 'iFruit tablet: lock screen, home, notifications, Settings, and the platform other resources add apps to'
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
    'server/exports.lua',
}

ui_page 'web/index.html'

files {
    'shared/*.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'web/kit/kit.css',
    'web/kit/kit.js',
}

dependencies {
    'city_ui',
    'city_inventory',
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
