fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_prison'
description 'Bolingbroke Penitentiary: serving sentences, prison jobs, contraband, escapes and the prison computer'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/life.lua',
    'client/escape.lua',
    'client/computer.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/life.lua',
    'server/escape.lua',
    'server/computer.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'city_ui',
    'city_inventory',
    'city_police',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'ox_doorlock',
    'qbx_core',
}
