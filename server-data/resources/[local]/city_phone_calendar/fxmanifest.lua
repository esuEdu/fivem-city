fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_calendar'
description 'Calendar app for city_phone: a month view of the real date'
version '0.1.0'

client_scripts {
    'client/main.lua',
}

files {
    'web/index.html',
    'web/icon.svg',
    'web/style.css',
    'web/js/*.js',
}

dependencies {
    'city_phone',
}
