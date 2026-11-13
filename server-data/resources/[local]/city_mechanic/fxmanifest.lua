fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_mechanic'
description 'Mechanic job: tuning bay, duty, shop storage, work vehicles, repair kits and the Mechanic tablet app'
version '0.2.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/kits.lua',
    'client/inspect.lua',
    'client/app.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qbx_core/modules/lib.lua',
    'server/main.lua',
    'server/tuning.lua',
    'server/kits.lua',
    'server/app/main.lua',
    'server/app/team.lua',
}

-- The tuning menu; the tablet app (web/app/) runs inside city_os
ui_page 'web/index.html'

files {
    'locales/*.json',
    'shared/*.lua',
    'client/tuning.lua',
    'client/camera.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/app/index.html',
    'web/app/app.css',
    'web/app/js/*.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_target',
    'city_points',
    'city_ui',
    'city_os',
    'city_inventory',
    'city_bank',
}
