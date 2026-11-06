fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_hospital'
description 'Hospital and EMS for fivem-city: downed screen, /finalizado, respawn, beds, reception, NPC ambulance and the EMS job'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/beds.lua',
    'client/ems.lua',
    'client/patient.lua',
    'client/carry.lua',
    'client/items.lua',
}

server_scripts {
    '@qbx_core/modules/lib.lua',
    'server/main.lua',
    'server/npc.lua',
    'server/hospital.lua',
    'server/ems.lua',
    'server/items.lua',
    'server/carry.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'client/npc.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'qbx_medical',
    'ox_target',
    'city_ui',
    'city_economy',
    'city_bank',
    'city_inventory',
}
