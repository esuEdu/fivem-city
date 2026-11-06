fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_bank'
description 'Bank branches for fivem-city: fingerprint registration and the personal account panel'
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
    'web/js/*.js',
}

dependencies {
    'city_ui',
    'city_economy',
    'ox_lib',
    'ox_target',
    'qbx_core',
}
