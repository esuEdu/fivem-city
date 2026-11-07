fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_garages'
description 'Unified garages and impound lots for fivem-city: any garage holds any of your cars, with a photo of each car before you take it out'
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
    'server/spawn.lua',
    'server/park.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'client/park.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'city_ui',
    'city_economy',
}
