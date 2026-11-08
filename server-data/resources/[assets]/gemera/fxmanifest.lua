fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gemera'
description 'Koenigsegg Gemera add-on car (model gemera, spawned from the staff tablet); meta files written for fivem-city'
version '1.0.0'

files {
    'data/vehiclelayouts.meta',
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carcols.meta',
    'data/carvariations.meta',
}

-- layouts first: vehicles.meta references GEMERA_COVER_OFFSET_INFO / LOW_GEMERA_FRONT_* defined there
data_file 'VEHICLE_LAYOUTS_FILE' 'data/vehiclelayouts.meta'
data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
-- mod kit before the variations that reference it (7491_gemera_modkit)
data_file 'CARCOLS_FILE' 'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'

-- in-game names for the gameName / vehicleMakeName / mod kit text keys
client_script 'names.lua'
