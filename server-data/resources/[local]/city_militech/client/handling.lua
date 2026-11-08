-- Reads a car's own handling and writes a setup over it. Handling changes are local to this client, so the stock
-- values are read the first time a car is touched here and kept per entity.
local tuning = require 'shared.tuning'

local handling = {}

local stockCache = {}

local CLASS = 'CHandlingData'

---@param vehicle integer
---@param field string
---@return number?
local function read(vehicle, field)
    local ok, value = pcall(tuning.fields[field].int and GetVehicleHandlingInt or GetVehicleHandlingFloat, vehicle, CLASS, field)
    if ok and type(value) == 'number' then return value end
end

---Forgets cars that are gone, so a reused entity handle never gets an old car's values
local function prune()
    for vehicle, entry in pairs(stockCache) do
        if not DoesEntityExist(vehicle) or GetEntityModel(vehicle) ~= entry.model then stockCache[vehicle] = nil end
    end
end

---The car's handling before any setup from this resource. Fields the game can't read are left out.
---@param vehicle integer
---@return table<string, number>
function handling.stock(vehicle)
    local entry = stockCache[vehicle]
    if entry and entry.model == GetEntityModel(vehicle) then return entry.values end

    prune()

    local values = {}

    for field in pairs(tuning.fields) do
        values[field] = read(vehicle, field)
    end

    stockCache[vehicle] = { model = GetEntityModel(vehicle), values = values }

    return values
end

---@param vehicle integer
---@return boolean
function handling.touched(vehicle)
    return stockCache[vehicle] ~= nil
end

---Writes a setup (already checked by the server) onto the car
---@param vehicle integer
---@param settings table<string, number>
function handling.apply(vehicle, settings)
    if not DoesEntityExist(vehicle) then return end

    local stock = handling.stock(vehicle)
    local values = tuning.effective(stock, settings or {}, Config.Params)

    for field, value in pairs(values) do
        local rule = tuning.fields[field]

        if not rule.readOnly then
            if rule.int then
                SetVehicleHandlingInt(vehicle, CLASS, field, math.floor(value))
            else
                SetVehicleHandlingFloat(vehicle, CLASS, field, value + 0.0)
            end
        end
    end

    if values.nInitialDriveGears then SetVehicleHighGear(vehicle, values.nInitialDriveGears) end

    -- top speed and drive force are cached by the game until the engine power is touched
    ModifyVehicleTopSpeed(vehicle, 1.0)
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
