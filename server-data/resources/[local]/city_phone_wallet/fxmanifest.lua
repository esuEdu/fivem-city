fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_phone_wallet'
description 'Wallet app for city_phone: city_bank on the phone (balance, statement, Pix, cards) and approving card purchases over the limit'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
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
    'city_phone',
    'city_bank',
}
