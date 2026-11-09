-- The prop being placed or edited (the "target"), the hover preview, and the boxes drawn around them.
local geometry = require 'shared.geometry'
local world = require 'client.world'
local freecam = require 'client.freecam'

local editor = {
    target = nil, ---@type table? { entity, model, hash, x, y, z, rx, ry, rz, collision, group, id?, original?, follow }
    preview = nil, ---@type table? { entity, model, hash, heading, distance, offset }
    picked = nil, ---@type table? a map prop clicked for hiding: { entity, hash, coords }
}

---@return boolean
function editor.validModel(model)
    return type(model) == 'string' and model:match('^[%w_%-]+$') ~= nil and #model <= 64 and IsModelInCdimage(joaat(model))
end

local function ghost(hash, coords, alpha)
    if not pcall(lib.requestModel, hash, 5000) then return end

    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if entity == 0 then return end

    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, alpha, false)

    return entity
end

---What the page shows about the target.
function editor.state()
    local t = editor.target
    if not t then return nil end

    return {
        id = t.id, model = t.model, follow = t.follow, collision = t.collision, group = t.group,
        x = t.x, y = t.y, z = t.z, rx = t.rx, ry = t.ry, rz = t.rz,
    }
end

function editor.apply()
    local t = editor.target
    if not t or not DoesEntityExist(t.entity) then return end

    world.place(t.entity, t)
end

---Starts placing a new prop of this model, following the cursor.
---@param from? table copy rotation, collision and group from this (duplicate)
function editor.startNew(model, from)
    editor.cancel()

    local hash = joaat(model)
    local coords = from and vector3(from.x, from.y, from.z) or freecam.coords() + vector3(geometry.forward(freecam.rotation())) * 5.0
    local entity = ghost(hash, coords, 200)
    if not entity then return false end

    editor.target = {
        entity = entity, model = model, hash = hash,
        x = coords.x, y = coords.y, z = coords.z,
        rx = from and from.rx or 0.0, ry = from and from.ry or 0.0, rz = from and from.rz or 0.0,
        collision = not from or from.collision, group = from and from.group,
        follow = from == nil,
    }

    editor.apply()

    return true
end

---Starts editing a placed prop: its own entity is moved, and put back if cancelled.
function editor.startEdit(id)
    editor.cancel()

    local prop, entity = world.props[id], world.spawned[id]
    if not prop or not entity then return false end

    world.locked[id] = true
    editor.target = {
        entity = entity, model = prop.model, hash = prop.hash, id = id,
        x = prop.x, y = prop.y, z = prop.z, rx = prop.rx, ry = prop.ry, rz = prop.rz,
        collision = prop.collision, group = prop.group, follow = false,
        original = { model = prop.model, x = prop.x, y = prop.y, z = prop.z, rx = prop.rx, ry = prop.ry, rz = prop.rz, collision = prop.collision, group = prop.group },
    }

    return true
end

---Drops the target: a new one is deleted, an edited one goes back to where it was saved.
function editor.cancel()
    local t = editor.target
    editor.target = nil
    if not t then return end

    if t.id then
        local prop = world.props[t.id]
        world.locked[t.id] = nil
        if prop and DoesEntityExist(t.entity) then world.place(t.entity, prop) end
    elseif DoesEntityExist(t.entity) then
        DeleteEntity(t.entity)
    end
end

---Forgets the target after it was saved (the server's update respawns it where it now is).
function editor.release()
    local t = editor.target
    editor.target = nil
    if not t then return end

    if t.id then
        world.locked[t.id] = nil
        world.despawn(t.id)
    elseif DoesEntityExist(t.entity) then
        DeleteEntity(t.entity)
    end
end

---The target as the server wants it.
function editor.payload()
    local t = editor.target
    if not t then return end

    return {
        id = t.id, model = t.model, x = t.x, y = t.y, z = t.z, rx = t.rx, ry = t.ry, rz = t.rz,
        collision = t.collision, group = t.group,
    }
end

---Puts the target on whatever is under a point of the screen, its bottom on the surface.
function editor.followScreen(sx, sy)
    local t = editor.target
    if not t then return end

    local hit, coords = freecam.raycast(sx, sy, t.entity)
    if not hit then return end

    local min = GetModelDimensions(t.hash)
    t.x, t.y, t.z = coords.x, coords.y, coords.z - min.z
    editor.apply()
end

---Drops the target straight down onto the ground below it, upright.
function editor.ground()
    local t = editor.target
    if not t then return end

    local handle = StartExpensiveSynchronousShapeTestLosProbe(t.x, t.y, t.z + 2.0, t.x, t.y, t.z - 100.0, 1 + 16, t.entity, 7)
    local _, hit, coords = GetShapeTestResult(handle)
    if hit ~= 1 then return end

    local min = GetModelDimensions(t.hash)
    t.z, t.rx, t.ry = coords.z - min.z, 0.0, 0.0
    editor.apply()
end

---One keyboard step: move relative to the camera, or rotate.
function editor.nudge(kind, dir, fine)
    local t = editor.target
    if not t or (dir ~= 1 and dir ~= -1) then return end

    local move = fine and Config.MoveStepFine or Config.MoveStep
    local turn = fine and Config.RotateStepFine or Config.RotateStep
    local _, yaw = freecam.rotation()

    if kind == 'forward' or kind == 'side' then
        local dx, dy = geometry.flatMove(yaw, kind == 'forward' and dir or 0, kind == 'side' and dir or 0)
        t.x, t.y = t.x + dx * move, t.y + dy * move
    elseif kind == 'up' then
        t.z = t.z + dir * move
    elseif kind == 'yaw' then
        t.rz = (t.rz + dir * turn + 180.0) % 360.0 - 180.0
    elseif kind == 'pitch' then
        t.rx = (t.rx + dir * turn + 180.0) % 360.0 - 180.0
    elseif kind == 'roll' then
        t.ry = (t.ry + dir * turn + 180.0) % 360.0 - 180.0
    else
        return
    end

    t.follow = false
    editor.apply()
end

---Exact values typed in the panel.
function editor.set(values)
    local t = editor.target
    if not t or type(values) ~= 'table' then return end

    for _, key in ipairs({ 'x', 'y', 'z', 'rx', 'ry', 'rz' }) do
        local value = tonumber(values[key])
        if value and value == value and math.abs(value) < 10000 then t[key] = value end
    end

    if values.collision ~= nil then t.collision = values.collision == true end
    if values.group ~= nil then
        local group = math.tointeger(values.group)
        t.group = group and group > 0 and group or nil
    end

    t.follow = false
    editor.apply()
end

---Shows a turning see-through copy of a model in front of the camera.
function editor.showPreview(model)
    editor.hidePreview()

    local hash = joaat(model)
    local entity = ghost(hash, freecam.coords(), 230)
    if not entity then return false end

    local min, max = GetModelDimensions(hash)
    local size = #(max - min)

    editor.preview = {
        entity = entity, model = model, hash = hash, heading = 0.0,
        distance = math.max(2.5, size * 1.6),
        offset = (min + max) / 2,
        size = { x = max.x - min.x, y = max.y - min.y, z = max.z - min.z },
    }

    return true
end

function editor.hidePreview()
    local preview = editor.preview
    editor.preview = nil

    if preview and DoesEntityExist(preview.entity) then DeleteEntity(preview.entity) end
end

local function updatePreview()
    local preview = editor.preview
    if not preview or not DoesEntityExist(preview.entity) then return end

    preview.heading = (preview.heading + GetFrameTime() * 40.0) % 360.0

    -- Turn around the model's middle, not its origin
    local h = math.rad(preview.heading)
    local o = preview.offset
    local center = freecam.coords() + vector3(geometry.forward(freecam.rotation())) * preview.distance
    local origin = center - vector3(o.x * math.cos(h) - o.y * math.sin(h), o.x * math.sin(h) + o.y * math.cos(h), o.z)

    SetEntityCoordsNoOffset(preview.entity, origin.x, origin.y, origin.z, false, false, false)
    SetEntityRotation(preview.entity, 0.0, 0.0, preview.heading, 2, false)
end

-- Corner pairs of a box whose corners are numbered 1-8 as (x, y, z) = min/max bits
local EDGES = { { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, { 1, 3 }, { 2, 4 }, { 5, 7 }, { 6, 8 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }

local function drawBox(entity, hash, r, g, b)
    if not entity or not DoesEntityExist(entity) then return end

    local min, max = GetModelDimensions(hash)
    local corners = {}

    for i = 0, 7 do
        local x = i % 2 == 0 and min.x or max.x
        local y = math.floor(i / 2) % 2 == 0 and min.y or max.y
        local z = i < 4 and min.z or max.z
        corners[i + 1] = GetOffsetFromEntityInWorldCoords(entity, x, y, z)
    end

    for _, edge in ipairs(EDGES) do
        local a, c = corners[edge[1]], corners[edge[2]]
        DrawLine(a.x, a.y, a.z, c.x, c.y, c.z, r, g, b, 255)
    end
end

---Every frame while the editor is open.
function editor.draw()
    updatePreview()

    local t = editor.target
    if t then
        if t.id then
            drawBox(t.entity, t.hash, 80, 200, 255)
        else
            drawBox(t.entity, t.hash, 245, 197, 66)
        end
    end

    local picked = editor.picked
    if picked then drawBox(picked.entity, picked.hash, 229, 72, 77) end
end

function editor.clear()
    editor.cancel()
    editor.hidePreview()
    editor.picked = nil
end

return editor
