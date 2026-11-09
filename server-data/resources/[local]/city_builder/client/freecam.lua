-- The editor's free camera: flies with WASD + mouse while the right mouse button is held, never too far from the ped.
local geometry = require 'shared.geometry'

local freecam = {}

local cam
local pitch, yaw = 0.0, 0.0

local CONTROLS = {
    lookX = 1, lookY = 2, forward = 32, back = 33, left = 34, right = 35,
    up = 38, down = 44, fast = 21, slow = 19,
}

function freecam.start()
    local coords = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)

    pitch, yaw = rotation.x, rotation.z
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z, pitch, 0.0, yaw, 60.0, false, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, true)
end

function freecam.stop()
    if not cam then return end

    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    cam = nil
end

---@return vector3
function freecam.coords()
    return GetCamCoord(cam)
end

function freecam.rotation()
    return pitch, yaw
end

---Points the camera at a spot from a few metres away.
function freecam.lookAt(target, distance)
    local back = vector3(geometry.forward(-25.0, yaw)) * distance
    local coords = target - back

    pitch = -25.0
    SetCamCoord(cam, coords.x, coords.y, coords.z)
    SetCamRot(cam, pitch, 0.0, yaw, 2)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

---Moves the camera from this frame's input. Call every frame while flying.
function freecam.fly()
    local frame = GetFrameTime()
    local sensitivity = Config.MouseSensitivity

    yaw = yaw - GetDisabledControlNormal(0, CONTROLS.lookX) * sensitivity
    pitch = math.max(-89.0, math.min(89.0, pitch - GetDisabledControlNormal(0, CONTROLS.lookY) * sensitivity))

    local speed = Config.CamSpeed * frame
    if IsDisabledControlPressed(0, CONTROLS.fast) then speed = speed * Config.CamFast end
    if IsDisabledControlPressed(0, CONTROLS.slow) then speed = speed / Config.CamSlow end

    local ahead = (IsDisabledControlPressed(0, CONTROLS.forward) and 1 or 0) - (IsDisabledControlPressed(0, CONTROLS.back) and 1 or 0)
    local side = (IsDisabledControlPressed(0, CONTROLS.right) and 1 or 0) - (IsDisabledControlPressed(0, CONTROLS.left) and 1 or 0)
    local lift = (IsDisabledControlPressed(0, CONTROLS.up) and 1 or 0) - (IsDisabledControlPressed(0, CONTROLS.down) and 1 or 0)

    local forward = vector3(geometry.forward(pitch, yaw))
    local right = vector3(geometry.right(yaw))
    local coords = GetCamCoord(cam) + (forward * ahead + right * side + vector3(0.0, 0.0, lift)) * speed

    -- Keep within reach of the character (the server checks the same distance)
    local origin = GetEntityCoords(cache.ped)
    local offset = coords - origin
    local length = #offset
    if length > Config.MaxCamDistance then coords = origin + offset / length * Config.MaxCamDistance end

    SetCamCoord(cam, coords.x, coords.y, coords.z)
    SetCamRot(cam, pitch, 0.0, yaw, 2)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

---What is under a point of the screen.
---@param sx number 0..1 from the left
---@param sy number 0..1 from the top
---@param ignore? integer entity the ray passes through
---@return boolean hit
---@return vector3 coords
---@return integer entity
function freecam.raycast(sx, sy, ignore)
    local origin = GetCamCoord(cam)
    local direction = vector3(geometry.screenRay(pitch, yaw, GetCamFov(cam), GetAspectRatio(false), sx, sy))
    local target = origin + direction * (Config.MaxCamDistance + 50.0)

    local handle = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, -1, ignore or 0, 7)
    local _, hit, coords, _, entity = GetShapeTestResult(handle)

    return hit == 1, coords, entity
end

return freecam
