fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_gangs'
description 'Gang app for the iFruit tablet: members, recruiting, ranks, the gang log and the drugs guide'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/members.lua',
    'server/recruit.lua',
}

files {
    'shared/*.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
}

dependencies {
    'city_os',
    'oxmysql',
    'ox_lib',
    'qbx_core',
}
