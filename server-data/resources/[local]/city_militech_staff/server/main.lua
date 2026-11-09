-- The staff tuner. Item + Config.Ace: the server checks every value against shared/fields.lua's hard limits, keeps
-- the setup on the car's `militechStaff` state bag (city_militech's client applies it, replacing the player's own
-- setup) and saves it for cars in player_vehicles. Every change goes to the staff log.
lib.locale()

local fields = require 'shared.fields'
local storage = require 'server.storage'

local sessions = {}
local lastApply = {}
local lastLoad = {}

---@param src integer
---@return boolean
local function isStaff(src)
    return IsPlayerAceAllowed(tostring(src), Config.Ace) == true
end

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

---@param src integer
---@param action string
---@param details string
local function staffLog(src, action, details)
    if GetResourceState('city_staff') ~= 'started' then return end
    exports.city_staff:Log(src, action, nil, details)
end

exports.qbx_core:CreateUseableItem(Config.Item, function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not isStaff(src) then
        lib.print.warn(('city_militech_staff: player %s used %s without %s'):format(src, Config.Item, Config.Ace))
        return exports.qbx_core:Notify(src, locale('error_not_staff'), 'error')
    end

    local vehicle = drivenVehicle(src)
    if not vehicle then return exports.qbx_core:Notify(src, locale('error_not_driver'), 'error') end
    if not stopped(vehicle) then return exports.qbx_core:Notify(src, locale('error_moving'), 'error') end

    local id = vehicleId(vehicle)
    local values = Entity(vehicle).state.militechStaff

    if values == nil and id then values = storage.get(id) end

    sessions[src] = { vehicle = vehicle, vehicleId = id }

    TriggerClientEvent('city_militech_staff:client:open', src, NetworkGetNetworkIdFromEntity(vehicle), values or {})
end)

lib.callback.register('city_militech_staff:apply', function(source, values)
    local src = source
    local session = sessions[src]
    local player = exports.qbx_core:GetPlayer(src)
    if not session or not player then return false, 'failed' end
    if not isStaff(src) then return false, 'not_staff' end

    local vehicle = drivenVehicle(src)
    if vehicle ~= session.vehicle then return false, 'not_driver' end
    if not stopped(vehicle) then return false, 'moving' end
    if exports.city_inventory:GetItemCount(src, Config.Item) < 1 then return false, 'no_item' end

    local now = os.time()
    if lastApply[src] and now - lastApply[src] < Config.ApplyCooldown then return false, 'wait' end

    local clean, badField = fields.validate(values)

    if not clean then
        lib.print.warn(('city_militech_staff: player %s sent an invalid setup (%s)'):format(src, badField))
        return false, 'failed'
    end

    lastApply[src] = now

    local count = 0
    for _ in pairs(clean) do count = count + 1 end

    Entity(vehicle).state:set('militechStaff', count > 0 and clean or false, true)

    if session.vehicleId then storage.set(session.vehicleId, clean, player.PlayerData.citizenid) end

    local plate = GetVehicleNumberPlateText(vehicle)

    if count > 0 then
        staffLog(src, 'militech_staff', ('%s: %d handling fields'):format(plate, count))
    else
        staffLog(src, 'militech_staff_reset', plate)
    end

    lib.print.info(('city_militech_staff: %s (%s) set %d fields on %s'):format(player.PlayerData.citizenid, src, count, plate))

    return true, clean
end)

-- A driver got into a car whose staff setup isn't on its state bag yet (called by city_militech's client)
lib.callback.register('city_militech_staff:load', function(source, netId)
    local src = source
    if type(netId) ~= 'number' then return end

    local now = os.time()
    if lastLoad[src] and now - lastLoad[src] < Config.LoadCooldown then return end
    lastLoad[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or vehicle ~= drivenVehicle(src) then return end

    local state = Entity(vehicle).state
    if state.militechStaff ~= nil then return end

    local id = vehicleId(vehicle)
    local values = id and storage.get(id)

    state:set('militechStaff', values or false, true)
end)

lib.callback.register('city_militech_staff:close', function(source)
    sessions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastApply[source] = nil
    lastLoad[source] = nil
end)
