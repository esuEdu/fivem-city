-- Parking: the owner, on foot next to their empty car, near any garage of its kind they may use

local garages = require 'server.garages'
local settings = require 'server.config'

local State = garages.State
local parking = {}

---@param vehicle integer
---@return boolean
local function isEmpty(vehicle)
    for seat = -1, 14 do
        if GetPedInVehicleSeat(vehicle, seat) ~= 0 then return false end
    end

    return true
end

---@param props any
---@param vehicle integer
---@return boolean
local function validProps(props, vehicle)
    if type(props) ~= 'table' or type(props.plate) ~= 'string' or type(props.model) ~= 'number' then return false end
    if garages.normalizePlate(props.plate) ~= garages.normalizePlate(GetVehicleNumberPlateText(vehicle)) then return false end
    if props.model ~= GetEntityModel(vehicle) then return false end

    local ok, encoded = pcall(json.encode, props)

    return ok and type(encoded) == 'string' and #encoded <= settings.maxPropsBytes
end

---@param garage table
---@param coords vector3
---@return boolean
local function inParkingArea(garage, coords)
    if #(coords - garage.coords.xyz) <= Config.ParkRadius then return true end

    for i = 1, #garage.spawns do
        if #(coords - garage.spawns[i].xyz) <= Config.ParkRadius then return true end
    end

    return false
end

-- The closest garage of this kind (not an impound lot) the player may park at, around the car
---@param src integer
---@param kind string
---@param coords vector3
---@return table?
local function parkingGarage(src, kind, coords)
    for _, garage in pairs(garages.all()) do
        if not garage.depot and garage.kind == kind and inParkingArea(garage, coords) then
            local allowed = not garage.groups or exports.qbx_core:HasPrimaryGroup(src, garage.groups)

            if allowed and garage.canAccess then
                local ok, result = pcall(garage.canAccess, src)
                allowed = ok and result
            end

            if allowed then return garage end
        end
    end
end

---@param src integer
---@param vehicle integer
---@param props table
---@return boolean, string?
local function park(src, vehicle, props)
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    if not player or ped <= 0 then return false, 'failed' end

    local coords = GetEntityCoords(vehicle)
    if #(GetEntityCoords(ped) - coords) > 6.0 then return false, 'too_far' end
    if GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src) then return false, 'failed' end
    if not isEmpty(vehicle) then return false, 'occupied' end
    if not validProps(props, vehicle) then return false, 'failed' end

    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    local playerVehicle = vehicleId and exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not playerVehicle then return false, 'not_owned' end

    local garage = parkingGarage(src, garages.kindOf(playerVehicle.modelName), coords)
    if not garage then return false, 'no_garage' end

    local saved = exports.qbx_vehicles:SaveVehicle(vehicle, { garage = garage.id, state = State.GARAGED, depotPrice = 0, props = props })
    if not saved then return false, 'failed' end

    exports.qbx_core:DeleteVehicle(vehicle)

    return true, garage.label
end

lib.callback.register('city_garages:park', function(source, netId, props)
    local src = source
    netId = math.tointeger(netId)
    if not netId then return false, 'failed' end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false, 'failed' end
    if parking[vehicle] then return false, 'busy' end

    parking[vehicle] = true
    local ok, parked, result = pcall(park, src, vehicle, props)
    parking[vehicle] = nil

    if not ok then
        lib.print.error(parked)
        return false, 'failed'
    end

    if not parked and result ~= 'occupied' and result ~= 'too_far' then
        lib.print.warn(('city_garages: %s could not park vehicle %s (%s)'):format(src, netId, result))
    end

    return parked, result
end)
