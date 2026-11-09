-- Keeps the driven car's handling in step with its `militech` state bag. Only the driver's client simulates the
-- car, so only the driver applies the setup.
lib.locale()

local handling = require 'client.handling'

local function driving(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == cache.ped
end

---@param vehicle integer
local function sync(vehicle)
    if not driving(vehicle) then return end

    local settings = Entity(vehicle).state.militech

    if settings == nil then
        -- the server puts the saved setup (or false) on the bag; the handler below applies it
        return lib.callback('city_militech:load', false, function() end,NetworkGetNetworkIdFromEntity(vehicle))
    end

    if settings then
        handling.apply(vehicle, settings)
    elseif handling.touched(vehicle) then
        handling.apply(vehicle, {})
    end
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

    handling.apply(vehicle, value or {})
end)

CreateThread(function()
    if cache.seat == -1 and cache.vehicle then sync(cache.vehicle) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    local vehicle = cache.vehicle
    if vehicle and handling.touched(vehicle) then handling.apply(vehicle, {}) end
end)
