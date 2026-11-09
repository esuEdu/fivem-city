-- Officer field tools: tackling (key while sprinting), the megaphone (key held in a police car) and forcing a locked
-- car open with the crowbar (ox_target on the car). The server checks each one again.

local job = require 'client.job'

local POLICE_CLASS = 18 -- emergency vehicles

---@param vehicle integer?
---@return boolean
local function inPoliceCar(vehicle)
    return vehicle ~= nil and vehicle ~= false and GetVehicleClass(vehicle) == POLICE_CLASS
end

-- Tackle: the closest player just in front of a sprinting officer
lib.addKeybind({
    name = 'police_tackle',
    description = locale('key_tackle'),
    defaultKey = Config.Keys.tackle,
    onPressed = function()
        if not job.onDuty() or cache.vehicle or not IsPedSprinting(cache.ped) then return end

        local front = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.2, 0.0)
        local player = lib.getClosestPlayer(front, Config.Ranges.tackle, false)
        if not player then return end

        local ok, reason = lib.callback.await('city_police:tackle', false, GetPlayerServerId(player))
        if not ok then
            if reason then job.fail(reason) end
            return
        end

        SetPedToRagdoll(cache.ped, Config.Tackle.officerMs, Config.Tackle.officerMs, 0, false, false, false)
    end,
})

RegisterNetEvent('city_police:client:tackled', function()
    SetPedToRagdoll(cache.ped, Config.Tackle.suspectMs, Config.Tackle.suspectMs, 0, false, false, false)
end)

-- Megaphone: a longer voice range while the key is held in a police car
local megaphoneOn = false

local function megaphoneOff()
    if not megaphoneOn then return end

    megaphoneOn = false
    exports['pma-voice']:clearProximityOverride()
end

lib.addKeybind({
    name = 'police_megaphone',
    description = locale('key_megaphone'),
    defaultKey = Config.Keys.megaphone,
    onPressed = function()
        if not job.onDuty() or not inPoliceCar(cache.vehicle) then return end

        megaphoneOn = true
        exports['pma-voice']:overrideProximityRange(Config.Megaphone.range, true)
        exports.qbx_core:Notify(locale('megaphone_on'), 'inform', 1500)
    end,
    onReleased = megaphoneOff,
})

lib.onCache('vehicle', function(vehicle)
    if not vehicle then megaphoneOff() end
end)

-- Crowbar: a locked car, police on duty
---@param vehicle integer
local function forceOpen(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local ok, reason = lib.callback.await('city_police:forceOpenStart', false, netId)
    if not ok then return job.fail(reason) end

    local done = lib.progressCircle({
        duration = Config.Crowbar.seconds * 1000,
        label = locale('forcing_open'),
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'missheistfbisetup1', clip = 'hassle_intro_loop_f', flag = 1 },
    })
    if not done then return end

    ok, reason = lib.callback.await('city_police:forceOpen', false, netId)
    if not ok then return job.fail(reason) end

    exports.qbx_core:Notify(locale('forced_open'), 'success')
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'city_police:forceOpen', label = locale('target_force_open'), icon = 'fas fa-unlock', distance = 2.5,
        canInteract = function(entity) return job.onDuty() and GetVehicleDoorLockStatus(entity) >= 2 end,
        onSelect = function(data) forceOpen(data.entity) end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    megaphoneOff()
    exports.ox_target:removeGlobalVehicle({ 'city_police:forceOpen' })
end)
