fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_inventory'
description 'Stand-in for ox_inventory: forwards its exports to city_inventory so Qbox scripts written for ox_inventory work unchanged'
-- Scripts check for ox_inventory by version (ox_fuel needs 2.30.0 and lists it as a dependency)
version '2.44.1'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_lib',
    'city_inventory',
}
