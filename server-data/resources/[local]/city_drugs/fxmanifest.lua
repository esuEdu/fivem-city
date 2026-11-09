fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_drugs'
description 'Drugs for gangs: weed, cocaine and meth, from picking to the labs to corner sales and bulk deals; the more it pays, the riskier'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/fields.lua',
    'client/labs.lua',
    'client/corner.lua',
    'client/deals.lua',
}

server_scripts {
    'server/main.lua',
    'server/fields.lua',
    'server/labs.lua',
    'server/corner.lua',
    'server/deals.lua',
    'server/guide.lua',
}

files {
    'locales/*.json',
    'shared/*.lua',
    'client/util.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'city_inventory',
}
