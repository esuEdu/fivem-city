-- Reads a car's own handling and writes setups over it. Handling changes are local to this client, so each field's
-- stock value is read the first time it's needed (before this file ever writes it) and kept per entity.
-- Field kinds follow GTA's names: n... = int, vec... = vector, anything else = float.
local tuning = require 'shared.tuning'

local handling = {}

local cars = {}

local CLASS = 'CHandlingData'
local EPSILON = 1e-5

---@param field string
---@return 'int' | 'vector' | 'float'
local function kind(field)
    if field:sub(1, 1) == 'n' then return 'int' end
    if field:sub(1, 3) == 'vec' then return 'vector' end
    return 'float'
end

---@param vehicle integer
---@param field string
---@return number | vector3 | nil
local function read(vehicle, field)
    local fieldKind = kind(field)
    local native = fieldKind == 'int' and GetVehicleHandlingInt
        or fieldKind == 'vector' and GetVehicleHandlingVector
        or GetVehicleHandlingFloat

    local ok, value = pcall(native, vehicle, CLASS, field)
    if not ok or value == nil then return end
    if fieldKind == 'vector' then return vector3(value.x, value.y, value.z) end
    if type(value) == 'number' then return value end
end

---@param vehicle integer
---@param field string
---@param value number | vector3 | table
local function write(vehicle, field, value)
    local fieldKind = kind(field)

    if fieldKind == 'int' then
        SetVehicleHandlingInt(vehicle, CLASS, field, math.floor(value + 0.5))
    elseif fieldKind == 'vector' then
        SetVehicleHandlingVector(vehicle, CLASS, field, vector3(value.x or value[1], value.y or value[2], value.z or value[3]))
    else
        SetVehicleHandlingFloat(vehicle, CLASS, field, value + 0.0)
    end
end

---@param a any
---@param b any
---@return boolean
local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < EPSILON end
    if a == nil or b == nil or type(a) == 'number' or type(b) == 'number' then return false end

    return math.abs((a.x or a[1]) - (b.x or b[1])) < EPSILON
        and math.abs((a.y or a[2]) - (b.y or b[2])) < EPSILON
        and math.abs((a.z or a[3]) - (b.z or b[3])) < EPSILON
end

---Forgets cars that are gone, so a reused entity handle never gets an old car's values
local function prune()
    for vehicle, car in pairs(cars) do
        if not DoesEntityExist(vehicle) or GetEntityModel(vehicle) ~= car.model then cars[vehicle] = nil end
    end
end

---@param vehicle integer
---@return table
local function entry(vehicle)
    local car = cars[vehicle]
    if car and car.model == GetEntityModel(vehicle) then return car end

    prune()

    car = { model = GetEntityModel(vehicle), stock = {}, read = {}, written = {} }
    cars[vehicle] = car

    return car
end

---The car's own value of each field, from before any setup. Fields the game can't read are left out.
---@param vehicle integer
---@param fields? string[] defaults to the fields shared/tuning.lua uses
---@return table<string, number | vector3>
function handling.stock(vehicle, fields)
    local car = entry(vehicle)

    if not fields then
        fields = {}
        for field in pairs(tuning.fields) do fields[#fields + 1] = field end
    end

    local values = {}

    for i = 1, #fields do
        local field = fields[i]

        if not car.read[field] then
            car.read[field] = true
            car.stock[field] = read(vehicle, field)
        end

        values[field] = car.stock[field]
    end

    return values
end

---@param vehicle integer
---@return boolean
function handling.touched(vehicle)
    local car = cars[vehicle]
    return car ~= nil and next(car.written) ~= nil
end

---Makes the car's handling exactly stock + target: fields written before and not in target go back to stock
---@param vehicle integer
---@param target table<string, number | vector3 | table>
function handling.set(vehicle, target)
    if not DoesEntityExist(vehicle) then return end

    local car = entry(vehicle)

    local fields = {}
    for field in pairs(target) do fields[#fields + 1] = field end
    for field in pairs(car.written) do fields[#fields + 1] = field end

    local stock = handling.stock(vehicle, fields)
    local gears

    for field in pairs(car.written) do
        if target[field] == nil and stock[field] ~= nil then
            write(vehicle, field, stock[field])
            car.written[field] = nil
            if field == 'nInitialDriveGears' then gears = stock[field] end
        end
    end

    for field, value in pairs(target) do
        if stock[field] ~= nil then
            if same(value, stock[field]) then
                if car.written[field] then write(vehicle, field, stock[field]) end
                car.written[field] = nil
            else
                write(vehicle, field, value)
                car.written[field] = true
            end

            if field == 'nInitialDriveGears' then gears = math.floor(value + 0.5) end
        end
    end

    if gears then SetVehicleHighGear(vehicle, gears) end

    -- top speed and drive force are cached by the game until the engine power is touched
    ModifyVehicleTopSpeed(vehicle, 1.0)
end

---Writes a Militech setup (already checked by the server) onto the car
---@param vehicle integer
---@param settings table<string, number>
function handling.apply(vehicle, settings)
    if not DoesEntityExist(vehicle) then return end

    local values = tuning.effective(handling.stock(vehicle), settings or {}, Config.Params)
    values.fMass = nil

    handling.set(vehicle, values)
end

---Mechanic upgrades that change the stats shown in the tuner
---@param vehicle integer
---@return table
function handling.upgrades(vehicle)
    SetVehicleModKit(vehicle, 0)

    return {
        engine = GetVehicleMod(vehicle, 11),
        brakes = GetVehicleMod(vehicle, 12),
        transmission = GetVehicleMod(vehicle, 13),
        turbo = IsToggleModOn(vehicle, 18),
    }
end

return handling
