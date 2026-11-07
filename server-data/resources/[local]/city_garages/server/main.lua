local garages = require 'server.garages'

local State = garages.State

lib.callback.register('city_garages:getGarages', function()
    local list = {}

    for id, garage in pairs(garages.all()) do
        list[id] = garages.public(garage)
    end

    return list
end)

---@param playerVehicle table
---@param plates table<string, true>
---@return string
local function stateOf(playerVehicle, plates)
    if playerVehicle.state == State.GARAGED then return 'garaged' end
    if playerVehicle.state == State.IMPOUNDED then return 'impounded' end

    local plate = playerVehicle.props and playerVehicle.props.plate
    if type(plate) == 'string' and plates[garages.normalizePlate(plate)] then return 'street' end

    return 'depot'
end

---@param value any
---@return integer
local function percent(value, max)
    return math.floor(math.max(0, math.min(100, (tonumber(value) or max) / max * 100)) + 0.5)
end

-- Every car of this garage's kind the player owns, with what can be done with it here
lib.callback.register('city_garages:getVehicles', function(source, garageId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local garage = garages.get(garageId)
    if not player or not garage then return end

    if not garages.canUse(src, garage) then
        lib.print.warn(('city_garages: %s asked for garage %s without access or too far'):format(src, garageId))
        return
    end

    local owned = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = player.PlayerData.citizenid })
    local plates = garages.platesInWorld()
    local list = {}

    for _, playerVehicle in ipairs(owned or {}) do
        if garages.kindOf(playerVehicle.modelName) == garage.kind and type(playerVehicle.props) == 'table' then
            local state = stateOf(playerVehicle, plates)
            local props = playerVehicle.props

            list[#list + 1] = {
                id = playerVehicle.id,
                model = playerVehicle.modelName,
                label = garages.label(playerVehicle.modelName),
                plate = props.plate,
                state = state,
                engine = percent(props.engineHealth, 1000),
                body = percent(props.bodyHealth, 1000),
                fuel = percent(props.fuelLevel, 100),
                fee = state == 'depot' and garages.depotFee(playerVehicle) or nil,
                image = Config.Images[playerVehicle.modelName] or Config.ImageUrl:format(playerVehicle.modelName),
            }
        end
    end

    return list
end)

---Adds a garage at runtime (e.g. a house garage). data = { label, kind = 'car'|'air'|'sea', coords = vector4,
---spawns = { vector4 }, depot?, groups?, blip? (false = none), ped? (false = a target zone instead of a ped),
---canAccess? = function(source) -> boolean }
---@param id string
---@param data table
---@return boolean
local function registerGarage(id, data)
    local garage = garages.register(id, data)
    if not garage then return false end

    -- rare (resource start, a house bought), and every client needs the new garage point
    TriggerClientEvent('city_garages:client:garageRegistered', -1, garages.public(garage))

    return true
end

exports('RegisterGarage', registerGarage)

exports('GetGarages', function()
    local list = {}

    for id, garage in pairs(garages.all()) do
        list[id] = garages.public(garage)
    end

    return list
end)
