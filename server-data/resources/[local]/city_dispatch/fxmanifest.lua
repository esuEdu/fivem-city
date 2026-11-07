fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_dispatch'
description 'Calls to the city services (police, EMS, mechanic) from the phone: responders get a notification, a blip and the /calls list'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'city_phone',
}
