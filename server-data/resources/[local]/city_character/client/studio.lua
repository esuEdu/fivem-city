-- The scene behind every screen: the ped in the lineup room, a scripted camera with a few shots, studio lights
local studio = {}

local active = false
local cam
local shot = 'body'
local lights = Config.Lights.studio
local zoom = 0.0

local function forward(heading)
    local rad = math.rad(heading)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function right(heading)
    local rad = math.rad(heading)
    return vector3(math.cos(rad), math.sin(rad), 0.0)
end

local function playIdle()
    local ped = cache.ped
    local sex = GetEntityModel(ped) == `mp_f_freemode_01` and 'f' or 'm'
    local idle = Config.Studio.idle[sex]

    lib.requestAnimDict(idle.dict)
    TaskPlayAnim(ped, idle.dict, idle.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(idle.dict)
end

-- How long to wait for the room's collision around a new ped, and for it to land on the floor, before freezing it anyway
local COLLISION_WAIT_MS = 1500
local LAND_WAIT_MS = 2000

-- Where the ped stands once it landed; the camera and the lights follow it, not Config.Studio.ped
local standing = vector3(Config.Studio.ped.x, Config.Studio.ped.y, Config.Studio.ped.z)

---Lets the ped drop onto the floor and waits until it stops moving
---@param ped integer
local function land(ped)
    local deadline = GetGameTimer() + LAND_WAIT_MS
    local last = GetEntityCoords(ped).z
    local still = 0

    repeat
        Wait(50)
        local z = GetEntityCoords(ped).z
        still = (math.abs(z - last) < 0.005 and not IsPedFalling(ped)) and still + 1 or 0
        last = z
    until still >= 3 or GetGameTimer() > deadline
end

local function placePed()
    -- After SetPlayerModel the player has a new ped; cache.ped only follows it on ox_lib's next tick
    local ped = PlayerPedId()
    cache.ped = ped
    local spot = Config.Studio.ped

    -- Freezing the ped right where it was put left it floating about a metre above the floor (head in the ceiling) after
    -- a model swap: drop it unfrozen once the room's collision is there, and freeze it where it lands
    FreezeEntityPosition(ped, false)
    RequestCollisionAtCoord(spot.x, spot.y, spot.z)
    SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
    SetEntityHeading(ped, spot.w)

    local deadline = GetGameTimer() + COLLISION_WAIT_MS
    repeat Wait(0) until HasCollisionLoadedAroundEntity(ped) or GetGameTimer() > deadline

    land(ped)

    -- Fell through a floor that never loaded: back to the configured spot
    if GetEntityCoords(ped).z < spot.z - 3.0 then
        SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
    end

    SetEntityHeading(ped, spot.w)
    FreezeEntityPosition(ped, true)
    standing = GetEntityCoords(ped)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    playIdle()
end

---Where the camera sits and looks for a shot, from the ped's spot (not its heading, so turning the ped spins it on screen)
local function framing(name)
    local spot = Config.Studio.ped
    local preset = Config.Cameras[name]
    local base = standing
    local dir = forward(spot.w)
    local distance = math.max(0.35, preset.distance - zoom)
    local target = base + vector3(0.0, 0.0, preset.height)

    if name == 'face' then
        local head = GetPedBoneCoords(cache.ped, 31086, 0.0, 0.0, 0.0)
        target = vector3(base.x, base.y, head.z + 0.02)
    end

    return target + dir * distance, target, preset.fov
end

local function pointCam(camera, name)
    local from, to, fov = framing(name)
    SetCamCoord(camera, from.x, from.y, from.z)
    PointCamAtCoord(camera, to.x, to.y, to.z)
    SetCamFov(camera, fov)
end

function studio.setShot(name, instant)
    if not Config.Cameras[name] or not cam then return end

    shot = name
    zoom = 0.0

    if instant then
        pointCam(cam, name)
        return
    end

    local nextCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    pointCam(nextCam, name)
    SetCamActiveWithInterp(nextCam, cam, 600, 1, 1)
    local oldCam = cam
    cam = nextCam

    SetTimeout(650, function()
        if DoesCamExist(oldCam) then DestroyCam(oldCam, false) end
    end)
end

function studio.zoom(delta)
    if not cam then return end

    local preset = Config.Cameras[shot]
    zoom = math.max(-1.0, math.min(preset.distance - 0.35, zoom + delta))
    pointCam(cam, shot)
end

function studio.shot()
    return shot
end

function studio.rotate(degrees)
    local ped = cache.ped
    SetEntityHeading(ped, (GetEntityHeading(ped) + degrees) % 360.0)
end

function studio.setLights(name)
    if Config.Lights[name] then lights = Config.Lights[name] end
end

function studio.refreshIdle()
    if active then playIdle() end
end

---Screen positions (0-1) of the face points, or nil while the face shot isn't on
function studio.facePoints()
    if not active or shot ~= 'face' then return nil end

    local ped = cache.ped
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local heading = GetEntityHeading(ped)
    local fwd, side = forward(heading), right(heading)
    local points = {}

    for i = 1, #Config.FacePoints do
        local point = Config.FacePoints[i]
        local o = point.offset
        local world = head + side * o.x + fwd * o.y + vector3(0.0, 0.0, o.z)
        local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)

        if onScreen then
            points[#points + 1] = { id = point.id, x = x, y = y }
        end
    end

    return points
end

local function drawLoop()
    CreateThread(function()
        while active do
            local spot = Config.Studio.ped
            local base = standing
            local fwd, side = forward(spot.w), right(spot.w)

            for i = 1, #lights do
                local light = lights[i]
                local o = light.offset
                local pos = base + side * o.x + fwd * o.y + vector3(0.0, 0.0, o.z)
                DrawLightWithRange(pos.x, pos.y, pos.z, light.color[1], light.color[2], light.color[3], light.range, light.intensity)
            end

            SetUseHiDof()
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

function studio.start()
    if active then
        placePed()
        return
    end

    active = true
    shot = 'body'
    zoom = 0.0
    lights = Config.Lights.studio

    DisplayRadar(false)
    placePed()

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    pointCam(cam, shot)
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.3)
    SetCamFarDof(cam, 4.0)
    SetCamDofStrength(cam, 0.6)
    RenderScriptCams(true, false, 0, true, true)

    drawLoop()
end

function studio.replacePed()
    placePed()
end

function studio.stop()
    if not active then return end

    active = false
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil

    local ped = cache.ped
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
end

function studio.isActive()
    return active
end

return studio
