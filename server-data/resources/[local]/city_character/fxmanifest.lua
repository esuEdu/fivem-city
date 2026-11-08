fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_character'
description 'Character select, identity and a sculpting creator with draggable face points (replaces qbx_core multicharacter)'
version '0.1.0'

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
    'shared/*.lua',
    'client/studio.lua',
    'client/look.lua',
    'client/creator.lua',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
}

dependencies {
    'city_ui',
    'illenium-appearance',
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
