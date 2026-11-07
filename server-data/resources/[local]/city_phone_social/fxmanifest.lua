fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_social'
description 'InstaPic app for city_phone: photo posts, likes, comments, follows and a feed, 24-hour stories, one account per character'
version '0.1.0'

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
    'server/accounts.lua',
    'server/posts.lua',
    'server/social.lua',
}

files {
    'web/index.html',
    'web/icon.svg',
    'web/style.css',
    'web/js/*.js',
    'web/locales/*.json',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'city_inventory',
    'city_phone',
    'city_phone_photos',
}
