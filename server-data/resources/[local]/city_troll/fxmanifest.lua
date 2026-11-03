fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_troll'
description 'Admin troll commands for fivem-city'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
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
