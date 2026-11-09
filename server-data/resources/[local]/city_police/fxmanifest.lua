fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_police'
description 'LSPD for fivem-city: the field job (duty, cuffs, vehicles, objects, evidence, cameras, radars) and the MDT tablet app'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/stations.lua',
    'client/interactions.lua',
    'client/restraints.lua',
    'client/tools.lua',
    'client/patrol.lua',
    'client/cuffed.lua',
    'client/objects.lua',
    'client/evidence.lua',
    'client/radar.lua',
    'client/dispatch.lua',
    'client/arrest.lua',
    'client/mdt.lua',
    'client/compat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/stations.lua',
    'server/interactions.lua',
    'server/search.lua',
    'server/restraints.lua',
    'server/tools.lua',
    'server/objects.lua',
    'server/evidence.lua',
    'server/radar.lua',
    'server/compat.lua',
    'server/mdt/app.lua',
    'server/mdt/people.lua',
    'server/mdt/vehicles.lua',
    'server/mdt/weapons.lua',
    'server/mdt/reports.lua',
    'server/mdt/warrants.lua',
    'server/mdt/bolos.lua',
    'server/mdt/charges.lua',
    'server/mdt/impounds.lua',
    'server/mdt/licences.lua',
    'server/mdt/evidence.lua',
    'server/mdt/management.lua',
}

-- The arrest screen and the camera overlay; the MDT itself (web/index.html) runs inside the tablet
ui_page 'web/screen.html'

files {
    'shared/*.lua',
    'client/job.lua',
    'client/cameras.lua',
    'client/bodycam.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/js/*.js',
    'web/screen.html',
    'web/screen.css',
    'web/screen.js',
}

dependencies {
    'city_os',
    'city_ui',
    'city_inventory',
    'city_bank',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'qbx_core',
    'qbx_vehiclekeys',
    'MugShotBase64',
}
