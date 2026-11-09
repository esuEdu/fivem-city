fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_radio'
description 'The radio list on screen: channel, who is in it and who is talking (pma-voice), movable and resizable'
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
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'pma-voice',
    'city_ui',
}
