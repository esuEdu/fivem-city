-- The Militech tuner. The server checks every setup against Config.Params, keeps it on the car's `militech` state
-- bag (the driver's client applies it to the handling) and saves it for cars in player_vehicles.
lib.locale()

local tuning = require 'shared.tuning'
local storage = require 'server.storage'

local sessions = {}
local lastApply = {}
local lastLoad = {}

---The car src is driving, or nil
---@param src integer
---@return integer?
local function drivenVehicle(src)
    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    return vehicle
end

---@param vehicle integer
---@return boolean
local function stopped(vehicle)
    return #GetEntityVelocity(vehicle) <= Config.MaxSpeed
end

---player_vehicles id of the car, when it's a player's car
---@param vehicle integer
---@return integer?
local function vehicleId(vehicle)
    return Entity(vehicle).state.vehicleid
        or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
end

---@param player table
---@return boolean
local function incapacitated(player)
    local metadata = player.PlayerData.metadata
    return metadata.isdead or metadata.inlaststand or metadata.ishandcuffed
end

exports.qbx_core:CreateUseableItem(Config.Item, function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or incapacitated(player) then return end

    local vehicle = drivenVehicle(src)
    if not vehicle then return exports.qbx_core:Notify(src, locale('error_not_driver'), 'error') end
    if not stopped(vehicle) then return exports.qbx_core:Notify(src, locale('error_moving'), 'error') end

    local id = vehicleId(vehicle)
    local settings = Entity(vehicle).state.militech

    if settings == nil and id then settings = storage.get(id) end

    sessions[src] = { vehicle = vehicle, vehicleId = id }

    TriggerClientEvent('city_militech:client:open', src, NetworkGetNetworkIdFromEntity(vehicle), settings or {})
end)

lib.callback.register('city_militech:apply', function(source, settings)
    local src = source
    local session = sessions[src]
    local player = exports.qbx_core:GetPlayer(src)
    if not session or not player or incapacitated(player) then return false, 'failed' end

    local vehicle = drivenVehicle(src)
    if vehicle ~= session.vehicle then return false, 'not_driver' end
    if not stopped(vehicle) then return false, 'moving' end
    if exports.city_inventory:GetItemCount(src, Config.Item) < 1 then return false, 'no_item' end

    local now = os.time()
    if lastApply[src] and now - lastApply[src] < Config.ApplyCooldown then return false, 'wait' end

    local clean, badKey = tuning.validate(settings, Config.Params)

    if not clean then
        lib.print.warn(('city_militech: player %s sent an invalid setup (%s)'):format(src, badKey))
        return false, 'failed'
    end

    lastApply[src] = now

    Entity(vehicle).state:set('militech', next(clean) and clean or false, true)

    if session.vehicleId then storage.set(session.vehicleId, clean) end

    local changes = 0
    for _ in pairs(clean) do changes = changes + 1 end

    lib.print.info(('city_militech: %s (%s) tuned %s (%d changes)'):format(player.PlayerData.citizenid, src,
        GetVehicleNumberPlateText(vehicle), changes))

    return true, clean
end)

-- A driver got into a car whose setup isn't on its state bag yet (just taken out of a garage, say)
lib.callback.register('city_militech:load', function(source, netId)
    local src = source
    if type(netId) ~= 'number' then return end

    local now = os.time()
    if lastLoad[src] and now - lastLoad[src] < Config.LoadCooldown then return end
    lastLoad[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or vehicle ~= drivenVehicle(src) then return end

    local state = Entity(vehicle).state
    if state.militech ~= nil then return end

    local id = vehicleId(vehicle)
    local settings = id and storage.get(id)

    state:set('militech', settings or false, true)
end)

lib.callback.register('city_militech:close', function(source)
    sessions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastApply[source] = nil
    lastLoad[source] = nil
end)
