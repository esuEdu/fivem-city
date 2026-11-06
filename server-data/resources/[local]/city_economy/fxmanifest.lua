fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_economy'
description 'Money ledger for fivem-city: accounts, atomic transfers, source allowlist and cheat flags'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/exports.lua',
    'server/qbx.lua',
    'server/honeypots.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
