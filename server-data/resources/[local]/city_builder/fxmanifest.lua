fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_builder'
description 'Builder: a staff tablet app and freecam editor to place, move, rotate, group and remove props, and hide map props'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/builder.lua',
    'client/app.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- The editor overlay; the tablet app (web/app/) runs inside city_os
ui_page 'web/index.html'

files {
    'shared/*.lua',
    'client/world.lua',
    'client/freecam.lua',
    'client/editor.lua',
    'client/history.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'web/props.txt',
    'web/app/index.html',
    'web/app/app.css',
    'web/app/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'oxmysql',
    'city_ui',
    'city_os',
}
