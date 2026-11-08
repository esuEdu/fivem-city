-- A camera orbiting the car while the tuning menu is open: drag to turn, wheel to zoom, each category has a view
local camera = {}

local cam, vehicle
local angle, height, zoom = 35.0, 0.6, 1.0

-- angle 0 = in front of the car, 90 = its right side; height in metres above the car's center
local VIEWS = {
    performance = { angle = 20.0, height = 0.9 },
    body = { angle = 35.0, height = 0.6 },
    paint = { angle = 140.0, height = 0.9 },
    wheels = { angle = 80.0, height = 0.0, zoom = 0.75 },
    lights = { angle = 0.0, height = 0.4 },
    extras = { angle = 180.0, height = 0.5 },
}

local function update()
    if not cam or not DoesEntityExist(vehicle) then return end

    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local distance = #(max - min) * 0.85 * zoom
    local rad = math.rad(angle)
    local position = GetOffsetFromEntityInWorldCoords(vehicle, math.sin(rad) * distance, math.cos(rad) * distance, height)
    local target = GetEntityCoords(vehicle)

    SetCamCoord(cam, position.x, position.y, position.z)
    PointCamAtCoord(cam, target.x, target.y, target.z + 0.1)
end

---@param entity integer
function camera.start(entity)
    vehicle = entity
    angle, height, zoom = VIEWS.body.angle, VIEWS.body.height, 1.0

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 50.0)
    update()
    RenderScriptCams(true, true, 600, true, true)
end

function camera.stop()
    if not cam then return end

    RenderScriptCams(false, true, 600, true, true)
    DestroyCam(cam, false)
    cam, vehicle = nil, nil
end

---@param dx number mouse pixels dragged sideways
---@param dy number mouse pixels dragged up/down
---@param wheel number mouse wheel steps (+ = out)
function camera.move(dx, dy, wheel)
    angle = (angle - dx * 0.35) % 360
    height = math.max(-0.3, math.min(2.5, height + dy * 0.01))
    zoom = math.max(0.55, math.min(1.6, zoom + wheel * 0.08))
    update()
end

---@param category string
function camera.focus(category)
    local view = VIEWS[category]
    if not view then return end

    angle, height, zoom = view.angle, view.height, view.zoom or 1.0
    update()
end

return camera
