-- The tuning bay. The mechanic (or staff, Config.StaffAce) previews on their own client (they drive the car, so they
-- own it); on confirm the server checks the cart against shared/catalog.lua, prices it, charges the mechanic job's
-- account (only with Config.Features.chargeJob, never for staff) and writes the changes into the car's saved props.
local catalog = require 'shared.catalog'
local mechanic = require 'server.mechanic'
local services = require 'server.app.services'
local appCore = require 'server.app.core'

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

---Whether this tuner's parts are charged to the mechanic job's account
---@param staff boolean?
---@return boolean
local function charged(staff)
    return Config.Features.chargeJob and not staff
end

-- The client asks once whether its player may use the bay as staff (to show the key prompt); the server checks again
lib.callback.register('city_mechanic:canTune', function(source)
    local player, staff = mechanic.tuner(source)

    return player ~= nil and staff == true
end)

lib.callback.register('city_mechanic:open', function(source, netId)
    local src = source
    local player, staff = mechanic.tuner(src)
    if not player or type(netId) ~= 'number' then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not canWorkOn(src, vehicle) then return end

    for other, session in pairs(sessions) do
        if other ~= src and session.vehicle == vehicle then return end
    end

    sessions[src] = { vehicle = vehicle }

    return {
        balance = charged(staff) and exports.city_bank:JobBalance(Config.Job) or 0,
        free = not charged(staff),
        repair = repairPrice(vehicle),
    }
end)

lib.callback.register('city_mechanic:buy', function(source, cart, repair)
    local src = source
    local session = sessions[src]
    local player, staff = mechanic.tuner(src)
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

    local plate = GetVehicleNumberPlateText(session.vehicle)

    if total > 0 and charged(staff) then
        local ok, err = exports.city_bank:ChargeJob(Config.Job, total, ('Parts: %s'):format(plate), player.PlayerData.citizenid)

        if not ok then return false, err end
    end

    save(session.vehicle, cart, repairCost > 0)

    services.record({
        plate = plate,
        citizenid = player.PlayerData.citizenid,
        name = appCore.fullName(player),
        parts = services.describe(cart),
        total = total,
        repaired = repairCost > 0,
        staff = staff == true,
    })

    lib.print.info(('city_mechanic: %s (%s) fitted %s worth $%d%s'):format(player.PlayerData.citizenid, src, plate, total,
        charged(staff) and '' or ' (free)'))

    if staff and GetResourceState('city_staff') == 'started' then
        local parts = 0
        for _ in pairs(cart) do parts = parts + 1 end

        exports.city_staff:Log(src, 'mechanic_tune', plate, ('%d parts, worth $%d%s'):format(parts, total,
            repairCost > 0 and ', repaired' or ''))
    end

    return true, {
        total = total,
        balance = charged(staff) and exports.city_bank:JobBalance(Config.Job) or 0,
        repaired = repairCost > 0,
    }
end)

lib.callback.register('city_mechanic:close', function(source)
    sessions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastBuy[source] = nil
end)
