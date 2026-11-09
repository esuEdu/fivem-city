-- The patrol car radar: speed and plate of the car ahead and behind, and the car's own speed (km/h). Only this client
-- reads it, so nothing is sent to the server. Runs only while turned on in a police car.

local job = require 'client.job'

local POLICE_CLASS = 18
local RANGE = Config.PatrolRadar.range

local on = false
local locked = false

---@param vehicle integer
---@param forward number 1 ahead, -1 behind
---@return { speed: integer, plate: string }?
local function read(vehicle, forward)
    local from = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, forward * 3.0, 0.4)
    local to = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, forward * RANGE, 0.4)
    local probe = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 2.0, 10, vehicle, 7)
    local _, hit, _, _, entity = GetShapeTestResult(probe)

    if hit ~= 1 or entity == 0 or GetEntityType(entity) ~= 2 then return end

    return { speed = math.floor(GetEntitySpeed(entity) * 3.6 + 0.5), plate = GetVehicleNumberPlateText(entity):match('^%s*(.-)%s*$') }
end

local function stop()
    on, locked = false, false
    SendNUIMessage({ action = 'radarOff' })
end

local function start()
    on = true

    CreateThread(function()
        while on do
            local vehicle = cache.vehicle
            if not vehicle or GetVehicleClass(vehicle) ~= POLICE_CLASS or not job.onDuty() then break end

            if not locked then
                SendNUIMessage({
                    action = 'radar',
                    own = math.floor(GetEntitySpeed(vehicle) * 3.6 + 0.5),
                    front = read(vehicle, 1),
                    rear = read(vehicle, -1),
                    labels = { front = locale('radar_front'), rear = locale('radar_rear'), own = locale('radar_own'), locked = locale('radar_locked') },
                })
            end

            Wait(Config.PatrolRadar.everyMs)
        end

        stop()
    end)
end

lib.addKeybind({
    name = 'police_radar',
    description = locale('key_radar'),
    defaultKey = Config.Keys.radar,
    onPressed = function()
        if on then return stop() end
        if not job.onDuty() or not cache.vehicle or GetVehicleClass(cache.vehicle) ~= POLICE_CLASS then return end

        start()
    end,
})

lib.addKeybind({
    name = 'police_radar_lock',
    description = locale('key_radar_lock'),
    defaultKey = Config.Keys.radarLock,
    onPressed = function()
        if not on then return end

        locked = not locked
        SendNUIMessage({ action = 'radarLock', locked = locked })
    end,
})
