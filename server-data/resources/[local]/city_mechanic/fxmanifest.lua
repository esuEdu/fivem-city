fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_mechanic'
description 'Mechanic job: tuning bay with a menu paid by the shop account, duty, shop storage, work vehicles and repair kits'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/kits.lua',
    'client/inspect.lua',
}

server_scripts {
    '@qbx_core/modules/lib.lua',
    'server/main.lua',
    'server/tuning.lua',
    'server/kits.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'shared/*.lua',
    'client/tuning.lua',
    'client/camera.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'city_ui',
    'city_inventory',
    'city_bank',
}
