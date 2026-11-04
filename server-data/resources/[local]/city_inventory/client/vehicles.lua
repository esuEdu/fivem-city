-- Which vehicle storage opening the inventory shows: the glovebox when sitting in a car, the trunk when standing at its
-- back. The server checks again (in the car, close enough, unlocked).

local TRUNK_DOOR = 5
local TRUNK_REACH = 1.5

local vehicles = {}

---@type integer? vehicle whose trunk lid we opened
local openTrunk

---@param vehicle integer
---@return boolean
local function atTrunk(vehicle)
    local min = GetModelDimensions(GetEntityModel(vehicle))
    local rear = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, min.y - 0.3, 0.0)

    return #(GetEntityCoords(cache.ped) - rear) <= TRUNK_REACH
end

---Opens the glovebox or trunk if the player is at one. Yields.
---@return boolean opened
---@return string? reason why a trunk or glovebox the player is at didn't open
function vehicles.open()
    if cache.vehicle then
        local success, reason = lib.callback.await('city_inventory:openVehicle', false, VehToNet(cache.vehicle), 'glovebox')
        return success, reason ~= 'no_storage' and reason or nil
    end

    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.TrunkDistance, false)
    if not vehicle or not atTrunk(vehicle) then return false end

    local success, reason = lib.callback.await('city_inventory:openVehicle', false, VehToNet(vehicle), 'trunk')
    if not success then return false, reason ~= 'no_storage' and reason or nil end

    openTrunk = vehicle
    SetVehicleDoorOpen(vehicle, TRUNK_DOOR, false, false)

    return true
end

---Shuts the trunk lid again.
function vehicles.close()
    if openTrunk and DoesEntityExist(openTrunk) then
        SetVehicleDoorShut(openTrunk, TRUNK_DOOR, false)
    end

    openTrunk = nil
end

-- The server closed it (walked away, the panel was replaced)
RegisterNetEvent('city_inventory:client:closeOther', vehicles.close)

return vehicles
