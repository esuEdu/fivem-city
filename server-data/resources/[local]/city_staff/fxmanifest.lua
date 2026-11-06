fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_staff'
description 'Staff app for the iFruit tablet: players, reports, warnings, bans, staff log and staff tools'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/target.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/players.lua',
    'server/sanctions.lua',
    'server/reports.lua',
    'server/self.lua',
}

files {
    'shared/*.lua',
    'client/self.lua',
    'client/spectate.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
}

dependencies {
    'city_os',
    'city_inventory',
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'qbx_medical',
}
