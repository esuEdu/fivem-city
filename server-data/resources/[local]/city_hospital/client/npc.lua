-- The "desperate prayer" scene: an ambulance appears on a road some way off, drives over with the siren on, a paramedic
-- walks up and does CPR. The server revives only if the scene took at least its minimum time.
local npc = {}

local CPR_MS = 9000
local MIN_SCENE_MS = 17000
local STUCK_MS = 8000
local ARRIVE_DISTANCE = 18.0
local DRIVE_FLAGS = 787004 -- rushed driving that still follows the roads

local scene

---@param model integer
---@param coords vector3
---@param heading number
---@return integer
local function spawnVehicle(model, coords, heading)
    lib.requestModel(model)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleSiren(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)

    return vehicle
end

---@param vehicle integer
---@return integer
local function spawnMedic(vehicle)
    lib.requestModel(Config.Npc.medic)
    local medic = CreatePedInsideVehicle(vehicle, 26, Config.Npc.medic, -1, true, false)
    SetModelAsNoLongerNeeded(Config.Npc.medic)
    SetBlockingOfNonTemporaryEvents(medic, true)
    SetPedKeepTask(medic, true)
    SetEntityInvincible(medic, true)

    return medic
end

-- A road node about spawnDistance away from the player, so the ambulance can drive in
---@param origin vector3
---@return vector3, number
local function roadSpot(origin)
    local angle = math.random() * math.pi * 2
    local distance = Config.Npc.spawnDistance
    local x, y = origin.x + math.cos(angle) * distance, origin.y + math.sin(angle) * distance
    local found, node, heading = GetClosestVehicleNodeWithHeading(x, y, origin.z, 1, 3.0, 0)

    if found then return node, heading end

    return vec3(x, y, origin.z), 0.0
end

local function alive()
    return scene ~= nil and LocalPlayer.state.isDead == true
end

---@param ms integer
---@return boolean still running
local function sleep(ms)
    local untilAt = GetGameTimer() + ms

    while GetGameTimer() < untilAt do
        if not alive() then return false end
        Wait(250)
    end

    return true
end

local function drive(vehicle, medic, target)
    local deadline = GetGameTimer() + Config.Npc.driveTimeout * 1000
    local stillSince

    TaskVehicleDriveToCoordLongrange(medic, vehicle, target.x, target.y, target.z, 25.0, DRIVE_FLAGS, ARRIVE_DISTANCE)

    while alive() and GetGameTimer() < deadline do
        if #(GetEntityCoords(vehicle) - target) <= ARRIVE_DISTANCE then return end

        -- Stuck in traffic or against a wall: the paramedic gets out and walks
        if GetEntitySpeed(vehicle) < 1.0 then
            stillSince = stillSince or GetGameTimer()
            if GetGameTimer() - stillSince > STUCK_MS then return end
        else
            stillSince = nil
        end

        Wait(500)
    end
end

local function walkTo(medic, target)
    TaskLeaveVehicle(medic, GetVehiclePedIsIn(medic, false), 0)
    sleep(1500)
    TaskGoToCoordAnyMeans(medic, target.x, target.y, target.z, 2.0, 0, false, 786603, 0.0)

    local deadline = GetGameTimer() + 25000

    while alive() and GetGameTimer() < deadline do
        if #(GetEntityCoords(medic) - target) < 1.6 then return end
        Wait(250)
    end

    -- Couldn't get there (fence, water, interior): just put them next to the patient
    local spot = GetOffsetFromEntityInWorldCoords(cache.ped, 0.8, 0.0, 0.0)
    SetEntityCoords(medic, spot.x, spot.y, spot.z, false, false, false, false)
end

local function cpr(medic)
    TaskTurnPedToFaceEntity(medic, cache.ped, 1000)
    sleep(1000)

    local anim = Config.Anims.cpr
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(medic, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function cleanup(current)
    if not current then return end

    local vehicle, medic = current.vehicle, current.medic

    -- Drive off, then disappear
    CreateThread(function()
        if DoesEntityExist(medic) and DoesEntityExist(vehicle) then
            ClearPedTasks(medic)
            TaskEnterVehicle(medic, vehicle, 10000, -1, 2.0, 1, 0)
            Wait(8000)
            if DoesEntityExist(medic) then TaskVehicleDriveWander(medic, vehicle, 20.0, DRIVE_FLAGS) end
            Wait(15000)
        end

        if DoesEntityExist(medic) then DeleteEntity(medic) end
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)
end

---@param token string from city_hospital:pray
function npc.start(token)
    if scene then return end

    local startedAt = GetGameTimer()
    local origin = GetEntityCoords(cache.ped)
    local spot, heading = roadSpot(origin)
    local vehicle = spawnVehicle(Config.Npc.vehicle, spot, heading)
    local medic = spawnMedic(vehicle)

    scene = { vehicle = vehicle, medic = medic }

    CreateThread(function()
        drive(vehicle, medic, origin)
        if not alive() then return npc.stop() end

        walkTo(medic, GetEntityCoords(cache.ped))
        if not alive() then return npc.stop() end

        cpr(medic)

        local left = math.max(CPR_MS, MIN_SCENE_MS - (GetGameTimer() - startedAt))
        if not sleep(left) then return npc.stop() end

        local revived = lib.callback.await('city_hospital:prayerDone', false, token)

        if not revived then exports.qbx_core:Notify(locale('notify_prayer_failed'), 'error') end

        npc.stop()
    end)
end

---@return boolean
function npc.active()
    return scene ~= nil
end

function npc.stop()
    local current = scene

    scene = nil
    cleanup(current)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not scene then return end

    if DoesEntityExist(scene.medic) then DeleteEntity(scene.medic) end
    if DoesEntityExist(scene.vehicle) then DeleteEntity(scene.vehicle) end
end)

return npc
