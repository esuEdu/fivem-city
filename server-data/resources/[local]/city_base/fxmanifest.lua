fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_base'
description 'Base resource for fivem-city custom features'
version '0.1.0'

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

dependencies {
    'ox_lib',
    'qbx_core',
}
