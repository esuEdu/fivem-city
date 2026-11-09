fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_robbery'
description 'Robberies: blowing ATMs open with C4 and robbing 24/7 stores, with a cash bag on the floor and a police call'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/bags.lua',
    'client/atm.lua',
    'client/store.lua',
}

server_scripts {
    'server/atm.lua',
    'server/store.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'city_inventory',
    'city_economy',
    'city_police',
    'ox_lib',
    'ox_target',
    'qbx_core',
}
