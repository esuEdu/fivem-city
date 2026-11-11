-- The shop camera: the player stands still where they are and a scripted camera frames the part being changed
local camera = {}

local cam
local shot = 'body'
local zoom = 0.0
local heading = 0.0

local function forward(deg)
    local rad = math.rad(deg)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function framing(name)
    local preset = Config.Shots[name] or Config.Shots.body
    local ped = cache.ped
    local target = GetPedBoneCoords(ped, preset.bone, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, preset.height)

    -- The camera keeps the heading the shop opened with, so turning the ped spins it on screen
    local dir = forward(heading)
    if preset.behind then dir = -dir end
    if preset.side then dir = forward(heading + 70.0) end

    local distance = math.max(0.35, preset.distance - zoom)
    return target + dir * distance, target, preset.fov
end

local function point(camera_, name)
    local from, to, fov = framing(name)
    SetCamCoord(camera_, from.x, from.y, from.z)
    PointCamAtCoord(camera_, to.x, to.y, to.z)
    SetCamFov(camera_, fov)
end

function camera.start()
    heading = GetEntityHeading(cache.ped)
    shot, zoom = 'body', 0.0

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    point(cam, shot)
    RenderScriptCams(true, true, 500, true, true)
end

function camera.setShot(name)
    if not cam or not Config.Shots[name] then return end

    shot, zoom = name, 0.0

    local nextCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    point(nextCam, name)
    SetCamActiveWithInterp(nextCam, cam, 500, 1, 1)

    local old = cam
    cam = nextCam
    SetTimeout(550, function()
        if DoesCamExist(old) then DestroyCam(old, false) end
    end)
end

function camera.zoom(delta)
    if not cam then return end

    local preset = Config.Shots[shot]
    zoom = math.max(-1.2, math.min(preset.distance - 0.35, zoom + delta))
    point(cam, shot)
end

function camera.rotate(degrees)
    local ped = cache.ped
    SetEntityHeading(ped, (GetEntityHeading(ped) + degrees) % 360.0)
end

function camera.stop()
    if not cam then return end

    RenderScriptCams(false, true, 500, true, true)
    if DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
end

return camera
