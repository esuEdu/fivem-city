fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_orgs'
description 'Faction (gang) tablet apps: vault, organization money, farm goals, management and activity log'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/app.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/app/main.lua',
    'server/app/vault.lua',
    'server/app/goals.lua',
    'server/app/team.lua',
}

files {
    'locales/*.json',
    'shared/*.lua',
    'web/app/index.html',
    'web/app/app.css',
    'web/app/js/*.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_target',
    'city_ui',
    'city_os',
    'city_inventory',
    'city_bank',
}
