-- What can be changed in the tuning bay, keyed by ox_lib vehicle property names, and what each change costs.
-- Plain data and math: the client builds the menu from it, the server validates and prices the cart with it.
local catalog = {}

local MAX_MOD = 255
local MAX_PAINT = 160

-- Body parts and interior: GTA mod slot -> ox_lib property
catalog.parts = {
    { slot = 0, key = 'modSpoilers', label = 'Spoiler' },
    { slot = 1, key = 'modFrontBumper', label = 'Front Bumper' },
    { slot = 2, key = 'modRearBumper', label = 'Rear Bumper' },
    { slot = 3, key = 'modSideSkirt', label = 'Side Skirts' },
    { slot = 4, key = 'modExhaust', label = 'Exhaust' },
    { slot = 5, key = 'modFrame', label = 'Roll Cage' },
    { slot = 6, key = 'modGrille', label = 'Grille' },
    { slot = 7, key = 'modHood', label = 'Hood' },
    { slot = 8, key = 'modFender', label = 'Left Fender' },
    { slot = 9, key = 'modRightFender', label = 'Right Fender' },
    { slot = 10, key = 'modRoof', label = 'Roof' },
    { slot = 25, key = 'modPlateHolder', label = 'Plate Holder' },
    { slot = 26, key = 'modVanityPlate', label = 'Vanity Plate' },
    { slot = 27, key = 'modTrimA', label = 'Trim' },
    { slot = 28, key = 'modOrnaments', label = 'Ornaments' },
    { slot = 29, key = 'modDashboard', label = 'Dashboard' },
    { slot = 30, key = 'modDial', label = 'Dials' },
    { slot = 31, key = 'modDoorSpeaker', label = 'Door Speakers' },
    { slot = 32, key = 'modSeats', label = 'Seats' },
    { slot = 33, key = 'modSteeringWheel', label = 'Steering Wheel' },
    { slot = 34, key = 'modShifterLeavers', label = 'Shifter' },
    { slot = 35, key = 'modAPlate', label = 'Plaque' },
    { slot = 36, key = 'modSpeakers', label = 'Speakers' },
    { slot = 37, key = 'modTrunk', label = 'Trunk' },
    { slot = 38, key = 'modHydrolic', label = 'Hydraulics' },
    { slot = 39, key = 'modEngineBlock', label = 'Engine Block' },
    { slot = 40, key = 'modAirFilter', label = 'Air Filter' },
    { slot = 41, key = 'modStruts', label = 'Struts' },
    { slot = 42, key = 'modArchCover', label = 'Arch Covers' },
    { slot = 43, key = 'modAerials', label = 'Aerials' },
    { slot = 44, key = 'modTrimB', label = 'Trim B' },
    { slot = 45, key = 'modTank', label = 'Fuel Tank' },
    { slot = 46, key = 'modWindows', label = 'Windows' },
    { slot = 47, key = 'modDoorR', label = 'Doors' },
    { slot = 48, key = 'modLivery', label = 'Livery' },
    { slot = 49, key = 'modLightbar', label = 'Lightbar' },
}

-- Upgrades with levels; prices per level come from Config.Prices.performance[key]
catalog.performance = {
    { slot = 11, key = 'modEngine', label = 'Engine' },
    { slot = 12, key = 'modBrakes', label = 'Brakes' },
    { slot = 13, key = 'modTransmission', label = 'Transmission' },
    { slot = 15, key = 'modSuspension', label = 'Suspension' },
    { slot = 16, key = 'modArmor', label = 'Armor' },
}

catalog.paints = {
    { key = 'color1', label = 'Primary' },
    { key = 'color2', label = 'Secondary' },
    { key = 'pearlescentColor', label = 'Pearlescent' },
    { key = 'wheelColor', label = 'Wheels' },
    { key = 'interiorColor', label = 'Interior' },
    { key = 'dashboardColor', label = 'Dashboard' },
}

local partKeys, performanceKeys, paintKeys = {}, {}, {}

for i = 1, #catalog.parts do partKeys[catalog.parts[i].key] = true end
for i = 1, #catalog.performance do performanceKeys[catalog.performance[i].key] = true end
for i = 1, #catalog.paints do paintKeys[catalog.paints[i].key] = true end

---@param value any
---@param min integer
---@param max integer
---@return boolean
local function int(value, min, max)
    return type(value) == 'number' and value == math.floor(value) and value >= min and value <= max
end

---@param value any
---@return boolean
local function rgb(value)
    return type(value) == 'table' and #value == 3 and int(value[1], 0, 255) and int(value[2], 0, 255) and int(value[3], 0, 255)
end

---@param value any
---@return boolean
local function neons(value)
    if type(value) ~= 'table' or #value ~= 4 then return false end

    for i = 1, 4 do
        if type(value[i]) ~= 'boolean' then return false end
    end

    return true
end

---Price of setting one property, or nil when the key or value isn't allowed
---@param key string
---@param value any
---@param prices table Config.Prices
---@return integer?
function catalog.price(key, value, prices)
    if partKeys[key] then return int(value, -1, MAX_MOD) and prices.part or nil end

    if performanceKeys[key] then
        local levels = prices.performance[key]
        if not levels or not int(value, -1, #levels - 1) then return end

        return value == -1 and 0 or levels[value + 1]
    end

    if paintKeys[key] then return int(value, 0, MAX_PAINT) and prices.paint or nil end

    if key == 'modHorns' then return int(value, -1, MAX_MOD) and prices.horn or nil end
    -- the rim type alone changes nothing visible; the rim is what is paid
    if key == 'wheels' then return int(value, 0, 12) and 0 or nil end
    if key == 'modFrontWheels' or key == 'modBackWheels' then return int(value, -1, MAX_MOD) and prices.wheels or nil end
    if key == 'modCustomTiresF' or key == 'modSmokeEnabled' then return type(value) == 'boolean' and prices.tyres or nil end
    if key == 'tyreSmokeColor' then return rgb(value) and prices.tyres or nil end
    if key == 'modXenon' then return type(value) == 'boolean' and prices.lights or nil end
    if key == 'xenonColor' then return (int(value, -1, 12) or value == 255) and prices.lights or nil end
    if key == 'neonEnabled' then return neons(value) and prices.lights or nil end
    if key == 'neonColor' then return rgb(value) and prices.lights or nil end
    if key == 'windowTint' then return int(value, -1, 6) and prices.tint or nil end
    if key == 'plateIndex' then return int(value, 0, 12) and prices.plate or nil end
    if key == 'modTurbo' then return type(value) == 'boolean' and (value and prices.turbo or 0) or nil end
end

---Repair price from the car's engine and body health (0-1000 each)
---@param engine number
---@param body number
---@param prices table
---@return integer
function catalog.repairPrice(engine, body, prices)
    local damage = math.max(0, 1000 - engine) + math.max(0, 1000 - body)

    return math.ceil(damage * prices.repairPerPoint)
end

catalog.MAX_ITEMS = 100

---Total of a cart { [propertyKey] = value }, or nil and the first key that isn't allowed
---@param cart any
---@param prices table
---@return integer? total
---@return string? badKey
function catalog.total(cart, prices)
    if type(cart) ~= 'table' then return nil, '?' end

    local total, count = 0, 0

    for key, value in pairs(cart) do
        count = count + 1
        if count > catalog.MAX_ITEMS or type(key) ~= 'string' then return nil, tostring(key) end

        local price = catalog.price(key, value, prices)
        if not price then return nil, key end

        total = total + price
    end

    return total
end

return catalog
