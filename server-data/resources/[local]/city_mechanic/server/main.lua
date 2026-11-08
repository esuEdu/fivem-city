-- Clock in, the shop's storage and work vehicles
lib.locale()

local mechanic = require 'server.mechanic'

local workVehicles = {}
local lastSpawn = {}

local SPAWN_COOLDOWN = 10

exports.city_inventory:RegisterStash(Config.Stash.id, locale('stash'), Config.Stash.slots, Config.Stash.weight, nil,
    { [Config.Job] = 0 }, Config.Stash.coords)

lib.callback.register('city_mechanic:duty', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or player.PlayerData.job.name ~= Config.Job then return end
    if not mechanic.near(src, Config.Duty, Config.UseDistance + 2.0) then return end

    local onDuty = not player.PlayerData.job.onduty
    exports.qbx_core:SetJobDuty(src, onDuty)

    return onDuty
end)

---@param src integer
local function removeWorkVehicle(src)
    local vehicle = workVehicles[src]
    workVehicles[src] = nil

    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end

lib.callback.register('city_mechanic:takeVehicle', function(source, index)
    local src = source
    if not mechanic.onDuty(src) then return false, 'not_on_duty' end

    local entry = math.type(index) == 'integer' and Config.Garage.vehicles[index]
    if not entry then return false, 'failed' end
    if not mechanic.near(src, Config.Garage.coords, 12.0) then return false, 'failed' end

    local now = os.time()
    if lastSpawn[src] and now - lastSpawn[src] < SPAWN_COOLDOWN then return false, 'wait' end
    if lib.getClosestVehicle(Config.Garage.spawn.xyz, 3.0, false) then return false, 'no_space' end

    lastSpawn[src] = now
    removeWorkVehicle(src)

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, {
        spawnSource = Config.Garage.spawn,
        model = joaat(entry.model),
        warp = GetPlayerPed(src),
        props = { plate = ('MECH%04d'):format(math.random(0, 9999)), fuelLevel = 100.0 },
    })

    if not ok or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        if not ok then lib.print.error(netId) end
        return false, 'failed'
    end

    workVehicles[src] = vehicle
    Entity(vehicle).state:set('mechanicWork', true, true)

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    end

    return true
end)

lib.callback.register('city_mechanic:storeVehicle', function(source)
    local src = source
    local vehicle = workVehicles[src]
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= vehicle then return false end
    if #(GetEntityCoords(vehicle) - Config.Garage.coords) > 12.0 then return false end

    removeWorkVehicle(src)

    return true
end)

AddEventHandler('playerDropped', function()
    removeWorkVehicle(source)
    lastSpawn[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(workVehicles) do
        removeWorkVehicle(src)
    end
end)
