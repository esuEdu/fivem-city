dofile('harness.lua')

local catalog = require 'shared.catalog'

local PRICES = {
    part = 500, paint = 1000, wheels = 1500, tyres = 750, lights = 750, tint = 500, plate = 250, horn = 250,
    turbo = 10000,
    performance = { modEngine = { 10000, 20000, 30000, 40000 }, modBrakes = { 2500, 5000, 7500 } },
    repairPerPoint = 2,
}

-- Body parts and paint cost a flat price; stock is a valid choice
check(catalog.price('modSpoilers', 3, PRICES) == 500, 'a body part costs the part price')
check(catalog.price('modSpoilers', -1, PRICES) == 500, 'going back to stock is allowed')
check(catalog.price('color1', 27, PRICES) == 1000, 'a paint costs the paint price')
check(catalog.price('color1', 500, PRICES) == nil, 'an unknown paint id is refused')

-- Performance: price per level, stock free, no level past the price list
check(catalog.price('modEngine', 0, PRICES) == 10000, 'engine level 1')
check(catalog.price('modEngine', 3, PRICES) == 40000, 'engine level 4')
check(catalog.price('modEngine', 4, PRICES) == nil, 'no engine level past the list')
check(catalog.price('modEngine', -1, PRICES) == 0, 'stock engine is free')
check(catalog.price('modEngine', 1.5, PRICES) == nil, 'levels must be whole numbers')
check(catalog.price('modArmor', 0, PRICES) == nil, 'an upgrade without prices is refused')

-- Toggles and colors
check(catalog.price('modTurbo', true, PRICES) == 10000, 'turbo costs its price')
check(catalog.price('modTurbo', false, PRICES) == 0, 'removing the turbo is free')
check(catalog.price('modTurbo', 1, PRICES) == nil, 'turbo must be a boolean')
check(catalog.price('neonColor', { 255, 0, 10 }, PRICES) == 750, 'a neon color')
check(catalog.price('neonColor', { 255, 0, 300 }, PRICES) == nil, 'color channels stay 0-255')
check(catalog.price('neonColor', { 255, 0 }, PRICES) == nil, 'a color has three channels')
check(catalog.price('neonEnabled', { true, true, false, false }, PRICES) == 750, 'neon sides')
check(catalog.price('neonEnabled', { true, 'x', false, false }, PRICES) == nil, 'neon sides are booleans')
check(catalog.price('xenonColor', 255, PRICES) == 750, 'the default xenon color')
check(catalog.price('wheels', 7, PRICES) == 0, 'the rim type alone is free')
check(catalog.price('modFrontWheels', 12, PRICES) == 1500, 'a rim costs the wheels price')
check(catalog.price('plateIndex', 12, PRICES) == 250, 'every plate style')

-- Anything else is refused
check(catalog.price('plate', 'FREE', PRICES) == nil, 'the plate text is not for sale')
check(catalog.price('engineHealth', 1000, PRICES) == nil, 'health is not a mod')

-- Cart totals
local total = catalog.total({ modSpoilers = 1, color1 = 12, modEngine = 1, modTurbo = true }, PRICES)
check(total == 500 + 1000 + 20000 + 10000, 'a cart adds up')

local bad, key = catalog.total({ modSpoilers = 1, fuelLevel = 100 }, PRICES)
check(bad == nil and key == 'fuelLevel', 'a cart with a bad key is refused and names it')
check(catalog.total('nope', PRICES) == nil, 'a cart must be a table')
check(catalog.total({}, PRICES) == 0, 'an empty cart costs nothing')

-- Repair
check(catalog.repairPrice(1000, 1000, PRICES) == 0, 'no damage, no repair cost')
check(catalog.repairPrice(500, 900, PRICES) == 1200, 'repair is priced per point of damage')
check(catalog.repairPrice(-4000, 1000, PRICES) == 10000, 'a wrecked engine counts from 1000')

finish()
