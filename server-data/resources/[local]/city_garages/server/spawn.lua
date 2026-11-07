-- Taking a car out: from any garage of its kind when it is parked, or from an impound lot (for a fee) when it was
-- left out and is no longer in the world. Police-impounded cars (state 2) stay with city_police until released.

local garages = require 'server.garages'
local settings = require 'server.config'

local State = garages.State
local spawning = {}

---@param garage table
---@return vector4?
local function freeSpawn(garage)
    for i = 1, #garage.spawns do
        local spawn = garage.spawns[i]
        if not lib.getClosestVehicle(spawn.xyz, Config.SpawnClearRadius, false) then return spawn end
    end
end

---@param src integer
---@param fee integer
---@return 'cash'|'bank'?
local function payFee(src, fee)
    if exports.qbx_core:GetMoney(src, 'cash') >= fee and exports.qbx_core:RemoveMoney(src, 'cash', fee, 'garage-depot') then
        return 'cash'
    end

    if exports.qbx_core:GetMoney(src, 'bank') >= fee and exports.qbx_core:RemoveMoney(src, 'bank', fee, 'garage-depot') then
        return 'bank'
    end
end

---@param src integer
---@param vehicle integer
---@param plate string
local function handOver(src, vehicle, netId, plate)
    if settings.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(vehicle, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
end

---@param src integer
---@param garage table
---@param vehicleId integer
---@return integer? netId, string? error
local function takeOut(src, garage, vehicleId)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil, 'failed' end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not playerVehicle then return nil, 'not_owned' end

    local props = playerVehicle.props
    if type(props) ~= 'table' or type(props.plate) ~= 'string' or type(props.model) ~= 'number' then return nil, 'failed' end
    if garages.kindOf(playerVehicle.modelName) ~= garage.kind then return nil, 'wrong_kind' end

    local fee = 0

    if garage.depot then
        if playerVehicle.state ~= State.OUT then return nil, 'not_in_depot' end
        if garages.platesInWorld()[garages.normalizePlate(props.plate)] then return nil, 'on_street' end
        fee = garages.depotFee(playerVehicle)
    elseif playerVehicle.state ~= State.GARAGED then
        return nil, 'not_parked'
    end

    local spawn = freeSpawn(garage)
    if not spawn then return nil, 'no_space' end

    local paidFrom = fee > 0 and payFee(src, fee)
    if fee > 0 and not paidFrom then return nil, 'no_money' end

    local function refund()
        if paidFrom then exports.qbx_core:AddMoney(src, paidFrom, fee, 'garage-refund') end
    end

    props.lockState = 1
    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { spawnSource = spawn, model = props.model, props = props })

    if not ok or not netId or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        refund()
        return nil, 'failed'
    end

    Entity(vehicle).state:set('vehicleid', vehicleId, false)

    local saved = exports.qbx_vehicles:SaveVehicle(vehicle, { state = State.OUT, depotPrice = 0 })
    if not saved then
        exports.qbx_core:DeleteVehicle(vehicle)
        refund()
        return nil, 'failed'
    end

    handOver(src, vehicle, netId, props.plate)
    TriggerEvent('city_garages:server:vehicleSpawned', vehicle, vehicleId, src)

    return netId
end

lib.callback.register('city_garages:takeOut', function(source, garageId, vehicleId)
    local src = source
    local garage = garages.get(garageId)
    vehicleId = math.tointeger(vehicleId)
    if not garage or not vehicleId then return nil, 'failed' end

    if not garages.canUse(src, garage) then
        lib.print.warn(('city_garages: %s tried to take a car out of %s without access or too far'):format(src, garageId))
        return nil, 'failed'
    end

    if spawning[vehicleId] then return nil, 'busy' end
    spawning[vehicleId] = true

    local ok, netId, err = pcall(takeOut, src, garage, vehicleId)
    spawning[vehicleId] = nil

    if not ok then
        lib.print.error(netId)
        return nil, 'failed'
    end

    return netId, err
end)
