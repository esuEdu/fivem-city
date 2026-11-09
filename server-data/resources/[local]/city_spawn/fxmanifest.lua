fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_spawn'
description 'Spawn picker after character select: one column per place, live camera preview (replaces qbx_spawn)'
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
    'city_ui',
    'ox_lib',
    'qbx_core',
    'spawnmanager',
}
