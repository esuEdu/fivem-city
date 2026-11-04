-- Trunks and gloveboxes: a stash per vehicle, keyed by plate (trunk:ABC123). Cars in player_vehicles keep theirs in the
-- database; anyone else's (locals' cars) only until the server restarts.

local stashes = require 'server.stashes'

local vehicles = {}

---@param entity integer
---@return string
local function plateOf(entity)
    local plate = (GetVehicleNumberPlateText(entity) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return plate
end

---@param plate string
---@return boolean
local function isOwned(plate)
    return MySQL.scalar.await('SELECT 1 FROM `player_vehicles` WHERE `plate` = ? LIMIT 1', { plate }) ~= nil
end

---Slots and weight for this vehicle's trunk or glovebox: a model override, else by vehicle type (nil = it has none).
---@param kind 'trunk' | 'glovebox'
---@param entity integer
---@return { slots: integer, maxWeight: integer }?
local function sizeOf(kind, entity)
    local override = Config.VehicleStorage.models[GetEntityModel(entity)]
    if override and override[kind] then return override[kind] end

    return Config.VehicleStorage[kind][GetVehicleType(entity)]
end

---@param entity integer
---@return boolean
local function isLocked(entity)
    -- qbx_vehiclekeys keeps the lock in this state bag (2 = locked)
    local state = Entity(entity).state.doorslockstate
    return (state or GetVehicleDoorLockStatus(entity)) == 2
end

---Opens a vehicle's trunk (standing next to it, unlocked) or glovebox (sitting in it).
---@param src integer
---@param netId unknown
---@param kind unknown 'trunk' or 'glovebox'
---@return boolean success
---@return string? reason
function vehicles.open(src, netId, kind)
    if kind ~= 'trunk' and kind ~= 'glovebox' then return false, 'no_stash' end

    netId = math.tointeger(tonumber(netId))
    local entity = netId and NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return false, 'no_vehicle' end

    local ped = GetPlayerPed(src)
    local inside = GetVehiclePedIsIn(ped, false)

    if kind == 'glovebox' then
        if inside ~= entity then return false, 'too_far' end
    else
        if inside ~= 0 or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > Config.TrunkDistance then return false, 'too_far' end
        if isLocked(entity) then return false, 'vehicle_locked' end
    end

    local size = sizeOf(kind, entity)
    if not size then return false, 'no_storage' end

    local plate = plateOf(entity)
    if plate == '' then return false, 'no_vehicle' end

    local id = ('%s:%s'):format(kind, plate)
    stashes.register(id, ('%s · %s'):format(locale(('ui_%s'):format(kind)), plate), size.slots, size.maxWeight, nil, nil, nil, not isOwned(plate))

    -- The checks above replace the stash's own (job, coords, hooks)
    return stashes.open(src, id, true)
end

return vehicles
