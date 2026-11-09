-- Officer field tools: tackling a suspect and forcing a locked car open with the crowbar.

local police = require 'server.police'
local settings = require 'server.config'

---@type table<integer, integer> officer -> last tackle (ms)
local lastTackle = {}

lib.callback.register('city_police:tackle', function(source, target)
    local src = source
    if not police.onDuty(src) or police.restrained(src) then return false end

    local now = GetGameTimer()
    if lastTackle[src] and now - lastTackle[src] < settings.tackleCooldown * 1000 then return false end

    target = police.reach(src, target, Config.Ranges.tackle + 1.0)
    if not target then return false, 'too_far' end

    local ped = GetPlayerPed(target)
    if GetVehiclePedIsIn(ped, false) ~= 0 or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'in_vehicle' end

    lastTackle[src] = now
    TriggerClientEvent('city_police:client:tackled', target)

    return true
end)

---@type table<integer, { vehicle: integer, at: integer }> officer -> the car they started forcing
local forcing = {}

---@param src integer
---@param netId unknown
---@return integer? vehicle
---@return string? reason
local function crowbarTarget(src, netId)
    if not police.onDuty(src) then return nil, 'off_duty' end
    if exports.city_inventory:GetItemCount(src, Config.Crowbar.item) < 1 then return nil, 'no_crowbar' end

    local vehicle = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil, 'no_vehicle' end
    if not police.near(src, GetEntityCoords(vehicle), Config.Ranges.vehicle) then return nil, 'too_far' end

    return vehicle
end

-- Two steps, so the time it takes is counted here and not by the client's progress bar
lib.callback.register('city_police:forceOpenStart', function(source, netId)
    local src = source
    local vehicle, reason = crowbarTarget(src, netId)
    if not vehicle then return false, reason end

    forcing[src] = { vehicle = vehicle, at = GetGameTimer() }

    return true
end)

lib.callback.register('city_police:forceOpen', function(source, netId)
    local src = source
    local vehicle, reason = crowbarTarget(src, netId)
    if not vehicle then return false, reason end

    local started = forcing[src]
    forcing[src] = nil
    if not started or started.vehicle ~= vehicle or GetGameTimer() - started.at < (Config.Crowbar.seconds - 1) * 1000 then
        police.warn(src, 'forced a car open too fast')
        return false
    end

    exports.qbx_vehiclekeys:SetLockState(vehicle, 'unlock')
    SetVehicleDoorsLocked(vehicle, 1)

    lib.print.info(('city_police: %s (%s) forced open %s'):format(police.name(src), src, GetVehicleNumberPlateText(vehicle)))

    return true
end)

AddEventHandler('playerDropped', function()
    lastTackle[source] = nil
    forcing[source] = nil
end)
