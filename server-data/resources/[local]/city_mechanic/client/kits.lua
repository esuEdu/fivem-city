-- Using a repair or cleaning kit next to a car: progress bar here, the server takes the item and says what it fixes
local busy = false

---@param vehicle integer
---@return boolean
local function takeControl(vehicle)
    if NetworkHasControlOfEntity(vehicle) then return true end

    local ok = pcall(lib.waitFor, function()
        if NetworkHasControlOfEntity(vehicle) then return true end
        NetworkRequestControlOfEntity(vehicle)
    end, nil, 2000)

    return ok
end

RegisterNetEvent('city_mechanic:client:useKit', function(name)
    local kit = Config.Kits[name]
    if busy or not kit or cache.vehicle then return end

    local vehicle = lib.getClosestVehicle(cache.coords, Config.KitDistance, false)
    if not vehicle then return exports.qbx_core:Notify(locale('error_no_vehicle'), 'error') end

    busy = true

    local done = lib.progressCircle({
        duration = kit.seconds * 1000,
        label = locale(kit.clean and 'cleaning' or 'repairing'),
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = kit.clean and { scenario = 'WORLD_HUMAN_MAID_CLEAN' } or { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },
    })

    if not done or not DoesEntityExist(vehicle) then
        busy = false
        return exports.qbx_core:Notify(locale('canceled'), 'error')
    end

    -- control first, so the item is only used when the fix can be applied
    if not takeControl(vehicle) then
        busy = false
        return exports.qbx_core:Notify(locale('error_failed'), 'error')
    end

    local result = lib.callback.await('city_mechanic:kit', false, name, NetworkGetNetworkIdFromEntity(vehicle))
    busy = false

    if not result then return exports.qbx_core:Notify(locale('error_failed'), 'error') end

    if result.clean then
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
        return exports.qbx_core:Notify(locale('cleaned'), 'success')
    end

    if result.full then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
    end

    SetVehicleEngineHealth(vehicle, math.max(GetVehicleEngineHealth(vehicle), result.engine + 0.0))
    SetVehicleUndriveable(vehicle, false)
    exports.qbx_core:Notify(locale('repaired'), 'success')
end)
