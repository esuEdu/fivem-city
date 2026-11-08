-- The tuning bay. The mechanic previews on their own client (they drive the car, so they own it); on confirm the
-- server checks the cart against shared/catalog.lua, prices it, charges the mechanic job's account and writes the
-- paid changes into the car's saved properties itself.
local catalog = require 'shared.catalog'
local mechanic = require 'server.mechanic'

local sessions = {}
local lastBuy = {}

local BUY_COOLDOWN = 2

---@param src integer
---@param vehicle integer
---@return boolean
local function canWorkOn(src, vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end
    if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then return false end

    return #(GetEntityCoords(vehicle) - Config.Bay.center) <= Config.Bay.radius
end

---@param vehicle integer
---@return integer
local function repairPrice(vehicle)
    return catalog.repairPrice(GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle), Config.Prices)
end

---@param vehicle integer
---@param cart table
---@param repaired boolean
local function save(vehicle, cart, repaired)
    local vehicleId = Entity(vehicle).state.vehicleid
        or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    if not vehicleId then return end

    local owned = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not owned then return end

    local props = type(owned.props) == 'table' and owned.props or {}

    for key, value in pairs(cart) do
        props[key] = value
    end

    if repaired then
        props.engineHealth = 1000.0
        props.bodyHealth = 1000.0
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, { props = props })
end

lib.callback.register('city_mechanic:open', function(source, netId)
    local src = source
    if not mechanic.onDuty(src) or type(netId) ~= 'number' then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not canWorkOn(src, vehicle) then return end

    for other, session in pairs(sessions) do
        if other ~= src and session.vehicle == vehicle then return end
    end

    sessions[src] = { vehicle = vehicle }

    return {
        balance = exports.city_bank:JobBalance(Config.Job) or 0,
        repair = repairPrice(vehicle),
    }
end)

lib.callback.register('city_mechanic:buy', function(source, cart, repair)
    local src = source
    local session = sessions[src]
    local player = mechanic.onDuty(src)
    if not session or not player then return false, 'failed' end
    if not canWorkOn(src, session.vehicle) then return false, 'not_in_bay' end

    local now = os.time()
    if lastBuy[src] and now - lastBuy[src] < BUY_COOLDOWN then return false, 'wait' end

    local total, badKey = catalog.total(cart, Config.Prices)

    if not total then
        lib.print.warn(('city_mechanic: player %s sent an invalid tuning change (%s)'):format(src, badKey))
        return false, 'failed'
    end

    local repairCost = repair == true and repairPrice(session.vehicle) or 0
    total = total + repairCost

    if next(cart) == nil and repairCost == 0 then return false, 'empty' end

    lastBuy[src] = now

    if total > 0 then
        local plate = GetVehicleNumberPlateText(session.vehicle)
        local ok, err = exports.city_bank:ChargeJob(Config.Job, total, ('Parts: %s'):format(plate), player.PlayerData.citizenid)

        if not ok then return false, err end
    end

    save(session.vehicle, cart, repairCost > 0)

    lib.print.info(('city_mechanic: %s (%s) fitted %s for $%d'):format(player.PlayerData.citizenid, src,
        GetVehicleNumberPlateText(session.vehicle), total))

    return true, { total = total, balance = exports.city_bank:JobBalance(Config.Job) or 0, repaired = repairCost > 0 }
end)

lib.callback.register('city_mechanic:close', function(source)
    sessions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastBuy[source] = nil
end)
