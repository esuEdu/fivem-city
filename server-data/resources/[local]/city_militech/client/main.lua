-- Keeps the driven car's handling in step with its state bags. Only the driver's client simulates the car, so only
-- the driver applies them. `militechStaff` (absolute values from city_militech_staff) replaces `militech` (the
-- player's setup) while it's there.
lib.locale()

local handling = require 'client.handling'

local STAFF_RESOURCE = 'city_militech_staff'

local function driving(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == cache.ped
end

---@param vehicle integer
---@param settings table|false|nil the player's setup
---@param staff table|false|nil staff values
local function refresh(vehicle, settings, staff)
    if staff then return handling.set(vehicle, staff) end
    if settings then return handling.apply(vehicle, settings) end
    if handling.touched(vehicle) then handling.set(vehicle, {}) end
end

---@param vehicle integer
local function sync(vehicle)
    if not driving(vehicle) then return end

    local state = Entity(vehicle).state
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- the servers put the saved setups (or false) on the bags; the handlers below apply them
    if state.militech == nil then
        lib.callback('city_militech:load', false, function() end, netId)
    end

    if state.militechStaff == nil and GetResourceState(STAFF_RESOURCE) == 'started' then
        lib.callback(('%s:load'):format(STAFF_RESOURCE), false, function() end, netId)
    end

    refresh(vehicle, state.militech, state.militechStaff)
end

lib.onCache('seat', function(seat)
    if seat ~= -1 then return end

    -- cache.vehicle may not be set yet in this same tick
    SetTimeout(0, function()
        sync(GetVehiclePedIsIn(cache.ped, false))
    end)
end)

AddStateBagChangeHandler('militech', nil, function(bagName, _, value)
    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle == 0 or not driving(vehicle) then return end

    refresh(vehicle, value, Entity(vehicle).state.militechStaff)
end)

AddStateBagChangeHandler('militechStaff', nil, function(bagName, _, value)
    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle == 0 or not driving(vehicle) then return end

    refresh(vehicle, Entity(vehicle).state.militech, value)
end)

-- Stock values for city_militech_staff's screen, read here so both use the same per-car stock
exports('Stock', function(vehicle, fields)
    if type(vehicle) ~= 'number' or not DoesEntityExist(vehicle) or type(fields) ~= 'table' then return {} end
    return handling.stock(vehicle, fields)
end)

CreateThread(function()
    if cache.seat == -1 and cache.vehicle then sync(cache.vehicle) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    local vehicle = cache.vehicle
    if vehicle and handling.touched(vehicle) then handling.set(vehicle, {}) end
end)
