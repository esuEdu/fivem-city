fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gemera'
description 'Koenigsegg Gemera add-on car (spawn name gemera); meta files written for fivem-city'
version '1.0.0'

files {
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carvariations.meta',
}

data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_script 'names.lua'

server_script 'server.lua'

dependencies {
    'ox_lib',
    'qbx_core',
}
