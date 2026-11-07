-- /gemera for every player (test server): one car each, replaced on the next spawn, with a cooldown
local MODEL = 'gemera'
local COOLDOWN_MS = 30000

---@type table<integer, integer> source -> their last spawned Gemera entity
local spawned = {}
---@type table<integer, integer> source -> GetGameTimer() of their last spawn
local lastSpawn = {}

local function deleteOwn(src)
    local vehicle = spawned[src]
    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    spawned[src] = nil
end

lib.addCommand('gemera', { help = 'Spawn a Koenigsegg Gemera' }, function(source)
    local src = source
    if src == 0 then return end

    if not exports.qbx_core:GetPlayer(src) then return end

    local now = GetGameTimer()
    if lastSpawn[src] and now - lastSpawn[src] < COOLDOWN_MS then
        local wait = math.ceil((COOLDOWN_MS - (now - lastSpawn[src])) / 1000)
        exports.qbx_core:Notify(src, ('Wait %d s before spawning another Gemera'):format(wait), 'error')
        return
    end

    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        exports.qbx_core:Notify(src, 'Get out of your vehicle first', 'error')
        return
    end

    deleteOwn(src)

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { model = MODEL, spawnSource = ped, warp = true })
    if not ok or not netId then
        -- Shows why in the txAdmin console, e.g. the model isn't streamed
        lib.print.error(('gemera: spawn failed for %s: %s'):format(src, ok and 'no vehicle' or netId))
        exports.qbx_core:Notify(src, 'The Gemera could not be spawned', 'error')
        return
    end

    spawned[src] = vehicle
    lastSpawn[src] = now

    if GetResourceState('qbx_vehiclekeys') == 'started' then exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end
end)

AddEventHandler('playerDropped', function()
    deleteOwn(source)
    lastSpawn[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for src in pairs(spawned) do deleteOwn(src) end
end)
