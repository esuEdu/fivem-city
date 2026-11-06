fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_bank'
description 'Banking for fivem-city: branches, accounts, cards, ATMs, card machines, transfers, bills, loans and bankers'
version '0.2.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/atm.lua',
    'client/pos.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/panel_accounts.lua',
    'server/panel_cards.lua',
    'server/panel_bills.lua',
    'server/atm.lua',
    'server/pos.lua',
    'server/staff.lua',
    'server/scheduler.lua',
    'server/devtools.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'client/nui.lua',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'web/js/tabs/*.js',
}

dependencies {
    'city_ui',
    'city_economy',
    'city_inventory',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'qbx_core',
}
