-- Test drives: a car spawned on the lot with the player inside, deleted when the time is up, when it goes too far,
-- or when the player leaves the server.
local catalog = require 'server.catalog'

local drives = {}
local lastDrive = {}

local COOLDOWN = 30

---@return vector4?
local function freeSpawn()
    local spawns = Config.TestDrive.spawns

    for i = 1, #spawns do
        if not lib.getClosestVehicle(spawns[i].xyz, Config.TestDrive.clearRadius, false) then return spawns[i] end
    end
end

---@param src integer
---@param notifyPlayer boolean
local function finish(src, notifyPlayer)
    local drive = drives[src]
    if not drive then return end

    drives[src] = nil

    if DoesEntityExist(drive.vehicle) then DeleteEntity(drive.vehicle) end
    if notifyPlayer then TriggerClientEvent('city_dealership:client:testDriveEnded', src) end
end

lib.callback.register('city_dealership:testDrive', function(source, model)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local entry = catalog.get(model)
    if not player or not entry then return false, 'failed' end
    if not catalog.atComputer(src) then return false, 'failed' end
    if drives[src] then return false, 'busy' end

    local now = os.time()
    if lastDrive[src] and now - lastDrive[src] < COOLDOWN then return false, 'wait' end

    local spawn = freeSpawn()
    if not spawn then return false, 'no_space' end

    lastDrive[src] = now
    drives[src] = { vehicle = 0 }

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, {
        spawnSource = spawn,
        model = entry.model,
        warp = GetPlayerPed(src),
        props = { plate = ('TEST%04d'):format(math.random(0, 9999)), fuelLevel = 100.0 },
    })

    if not ok or not netId or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        drives[src] = nil
        if not ok then lib.print.error(netId) end
        return false, 'failed'
    end

    if not drives[src] then
        -- the player left while it spawned
        DeleteEntity(vehicle)
        return false, 'failed'
    end

    drives[src] = { vehicle = vehicle, endsAt = now + Config.TestDrive.seconds }
    Entity(vehicle).state:set('testDrive', true, true)

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    end

    return true, Config.TestDrive.seconds
end)

lib.callback.register('city_dealership:endTestDrive', function(source)
    finish(source, true)
    return true
end)

CreateThread(function()
    local center = Config.Blip.coords

    while true do
        Wait(1000)

        local now = os.time()

        for src, drive in pairs(drives) do
            if drive.endsAt then
                local gone = not DoesEntityExist(drive.vehicle)
                local tooFar = not gone and #(GetEntityCoords(drive.vehicle) - center) > Config.TestDrive.maxDistance

                if gone or tooFar or now >= drive.endsAt then finish(src, true) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    finish(source, false)
    lastDrive[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(drives) do
        finish(src, true)
    end
end)
