-- Staff tools on themselves (noclip, invisible, godmode, names, blips) and vehicles. The server only checks
-- permission and logs; the staff member's client does the toggles.

local staff = require 'server.staff'

local TOGGLES = { 'noclip', 'invisible', 'godmode', 'names', 'blips' }

---@type table<integer, true> staff with player blips on
local blipViewers = {}
local blipLoop = false

local function sendBlips()
    local list = {}

    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        list[#list + 1] = { id = src, name = GetPlayerName(src), x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
    end

    for src in pairs(blipViewers) do
        TriggerClientEvent('city_staff:client:blips', src, list)
    end
end

local function startBlips()
    if blipLoop then return end
    blipLoop = true

    CreateThread(function()
        while next(blipViewers) do
            sendBlips()
            Wait(Config.BlipSeconds * 1000)
        end

        blipLoop = false
    end)
end

for _, tool in ipairs(TOGGLES) do
    staff.register(tool, function(src, data)
        local on = data.on == true

        if tool == 'blips' then
            blipViewers[src] = on or nil
            if on then startBlips() end
        end

        staff.log(src, tool, nil, on and 'on' or 'off')

        return true, on
    end)
end

staff.register('spawnVehicle', function(src, data)
    local model = type(data.model) == 'string' and data.model:lower()
    if not model or not exports.qbx_core:GetVehiclesByName()[model] then return false, 'unknown_model' end

    local ped = GetPlayerPed(src)
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 then DeleteEntity(current) end

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { model = model, spawnSource = ped, warp = true })
    if not ok or not netId then return false, 'failed' end

    if GetResourceState('qbx_vehiclekeys') == 'started' then exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end

    staff.log(src, 'spawnVehicle', nil, model)

    return true, netId
end)

-- The client repairs the staff member's own vehicle once this says yes
staff.register('fixVehicle', function(src)
    staff.log(src, 'fixVehicle')

    return true
end)

staff.register('deleteVehicle', function(src, data)
    local netId = math.tointeger(tonumber(data.netId))
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false, 'no_vehicle' end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle)) > Config.DeleteVehicleDistance then return false, 'too_far' end

    local plate = GetVehicleNumberPlateText(vehicle)
    DeleteEntity(vehicle)
    staff.log(src, 'deleteVehicle', nil, plate)

    return true
end)

---Saves the vehicle the staff member sits in to their own garage (qbx_vehicles).
staff.register('saveVehicle', function(src, data)
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if vehicle == 0 then return false, 'no_vehicle' end

    local info = exports.qbx_core:GetVehiclesByHash()[GetEntityModel(vehicle)]
    if not info then return false, 'unknown_model' end

    local citizenid = exports.qbx_core:GetPlayer(src).PlayerData.citizenid
    local existing = Entity(vehicle).state.vehicleid

    if existing then
        local success = exports.qbx_vehicles:SetPlayerVehicleOwner(existing, citizenid)
        if not success then return false, 'failed' end
    else
        local props = type(data.props) == 'table' and data.props or {}
        local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({ model = info.model, citizenid = citizenid, props = props })
        if not vehicleId then return false, 'failed' end

        Entity(vehicle).state:set('vehicleid', vehicleId, true)
    end

    staff.log(src, 'saveVehicle', nil, info.model)

    return true
end)

AddEventHandler('playerDropped', function()
    blipViewers[source] = nil
end)
