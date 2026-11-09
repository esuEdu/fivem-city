-- Camera math for the freecam editor, on plain numbers (tested in tests/city_builder/).
local geometry = {}

local rad, sin, cos, tan, sqrt = math.rad, math.sin, math.cos, math.tan, math.sqrt

local function normalize(x, y, z)
    local length = sqrt(x * x + y * y + z * z)
    if length == 0 then return 0.0, 0.0, 0.0 end

    return x / length, y / length, z / length
end

geometry.normalize = normalize

---Where a camera with this rotation (degrees, rotation order 2) looks.
function geometry.forward(pitch, yaw)
    local p, y = rad(pitch), rad(yaw)

    return -sin(y) * cos(p), cos(y) * cos(p), sin(p)
end

---The camera's right, flat on the ground.
function geometry.right(yaw)
    local y = rad(yaw)

    return cos(y), sin(y), 0.0
end

---The camera's up: right x forward.
function geometry.up(pitch, yaw)
    local fx, fy, fz = geometry.forward(pitch, yaw)
    local rx, ry, rz = geometry.right(yaw)

    return ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
end

---The direction through a point of the screen.
---@param pitch number camera pitch, degrees
---@param yaw number camera yaw, degrees
---@param fov number vertical field of view, degrees
---@param aspect number width / height
---@param sx number 0 (left) to 1 (right)
---@param sy number 0 (top) to 1 (bottom)
function geometry.screenRay(pitch, yaw, fov, aspect, sx, sy)
    local fx, fy, fz = geometry.forward(pitch, yaw)
    local rx, ry, rz = geometry.right(yaw)
    local ux, uy, uz = geometry.up(pitch, yaw)

    local half = tan(rad(fov) / 2)
    local h = (sx * 2 - 1) * half * aspect
    local v = (1 - sy * 2) * half

    return normalize(fx + rx * h + ux * v, fy + ry * h + uy * v, fz + rz * h + uz * v)
end

---An arrow key nudge relative to where the camera faces, flat on the ground: forward/back and left/right.
---@param yaw number camera yaw, degrees
---@param ahead number +1 forward, -1 back
---@param side number +1 right, -1 left
function geometry.flatMove(yaw, ahead, side)
    local fx, fy = geometry.forward(0, yaw)
    local rx, ry = geometry.right(yaw)

    return fx * ahead + rx * side, fy * ahead + ry * side
end

return geometry
