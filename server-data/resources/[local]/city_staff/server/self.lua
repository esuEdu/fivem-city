-- Staff tools on themselves (noclip, invisible, godmode, names, blips) and spawning vehicles. The server only checks
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

-- city_clothing checks its own ACE again and writes the start and the result to the staff log
staff.register('clothingPhotos', function(src, data)
    if GetResourceState('city_clothing') ~= 'started' then return false, 'unavailable' end

    return exports.city_clothing:StartPhotos(src, data)
end)

AddEventHandler('playerDropped', function()
    blipViewers[source] = nil
end)
