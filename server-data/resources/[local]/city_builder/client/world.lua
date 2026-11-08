-- The placed world on this client: props spawned locally (not networked) near the camera, and map props hidden.
local world = {
    props = {}, ---@type table<integer, table>
    groups = {}, ---@type table<integer, table>
    hides = {}, ---@type table<integer, table>
    spawned = {}, ---@type table<integer, integer> prop id -> entity
    byEntity = {}, ---@type table<integer, integer> entity -> prop id
    locked = {}, ---@type table<integer, boolean> props the editor is moving: kept spawned and not reset
    builder = false,
}

local CELL = 100.0
local cells = {}

local function cellKey(x, y)
    return ('%d:%d'):format(math.floor(x / CELL), math.floor(y / CELL))
end

local function unindex(prop)
    local cell = prop.cell and cells[prop.cell]
    if cell then cell[prop.id] = nil end
end

local function index(prop)
    prop.cell = cellKey(prop.x, prop.y)
    cells[prop.cell] = cells[prop.cell] or {}
    cells[prop.cell][prop.id] = true
end

local function groupHidden(prop)
    local group = prop.group and world.groups[prop.group]

    return group ~= nil and not group.enabled
end

local function visible(prop)
    return world.builder or not groupHidden(prop)
end

function world.despawn(id)
    local entity = world.spawned[id]
    if not entity then return end

    if DoesEntityExist(entity) then DeleteEntity(entity) end
    world.byEntity[entity] = nil
    world.spawned[id] = nil
end

---Puts an entity where a prop says (also used by the editor to reset a cancelled move).
function world.place(entity, prop)
    SetEntityCoordsNoOffset(entity, prop.x, prop.y, prop.z, false, false, false)
    SetEntityRotation(entity, prop.rx, prop.ry, prop.rz, 2, false)
end

local function spawn(prop)
    if not IsModelInCdimage(prop.hash) then return end

    local loaded = pcall(lib.requestModel, prop.hash, 5000)
    if not loaded or world.spawned[prop.id] or world.props[prop.id] ~= prop then return end

    local entity = CreateObjectNoOffset(prop.hash, prop.x, prop.y, prop.z, false, false, false)
    SetModelAsNoLongerNeeded(prop.hash)
    if entity == 0 then return end

    world.place(entity, prop)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, prop.collision, prop.collision)
    SetEntityInvincible(entity, true)
    SetEntityCanBeDamaged(entity, false)

    -- A hidden group still shows in the editor, see-through
    if groupHidden(prop) then SetEntityAlpha(entity, 120, false) end

    world.spawned[prop.id] = entity
    world.byEntity[entity] = prop.id
end

---@param props table[] new or changed props
function world.set(props)
    for _, data in ipairs(props) do
        local old = world.props[data.id]
        if old then unindex(old) end

        local prop = {
            id = data.id, model = data.model, hash = joaat(data.model),
            x = data.x, y = data.y, z = data.z, rx = data.rx, ry = data.ry, rz = data.rz,
            collision = data.collision, group = data.group,
        }

        world.props[prop.id] = prop
        index(prop)

        if world.locked[prop.id] then
            local entity = world.spawned[prop.id]
            if entity then world.place(entity, prop) end
        else
            world.despawn(prop.id)
        end
    end
end

---@param ids integer[]
function world.remove(ids)
    for _, id in ipairs(ids) do
        local prop = world.props[id]

        if prop then
            unindex(prop)
            world.props[id] = nil
        end

        world.locked[id] = nil
        world.despawn(id)
    end
end

function world.setGroups(groups)
    for _, group in ipairs(groups) do
        world.groups[group.id] = { id = group.id, name = group.name, enabled = group.enabled }
    end

    world.refresh()
end

function world.removeGroup(id)
    world.groups[id] = nil
    world.refresh()
end

function world.hide(hide)
    world.hides[hide.id] = hide
    CreateModelHideExcludingScriptObjects(hide.x, hide.y, hide.z, hide.radius, hide.model, true)
end

function world.unhide(id)
    local hide = world.hides[id]
    if not hide then return end

    RemoveModelHide(hide.x, hide.y, hide.z, hide.radius, hide.model, false)
    world.hides[id] = nil
end

---Despawns every prop that isn't being moved, so the loop spawns them again as they should look now.
function world.refresh()
    for id in pairs(world.spawned) do
        if not world.locked[id] then world.despawn(id) end
    end
end

---Replaces the whole world (first load, or the server restarted the resource's data).
function world.load(snapshot)
    for id in pairs(world.hides) do world.unhide(id) end
    for id in pairs(world.spawned) do world.despawn(id) end

    world.props, world.groups, world.locked, cells = {}, {}, {}, {}

    for _, group in ipairs(snapshot.groups) do world.groups[group.id] = group end
    world.set(snapshot.props)
    for _, hide in ipairs(snapshot.hides) do world.hide(hide) end
end

---@return table[] props sorted by distance from a point, up to limit
function world.nearest(origin, limit)
    local list = {}

    for _, prop in pairs(world.props) do
        list[#list + 1] = { prop = prop, distance = #(origin - vector3(prop.x, prop.y, prop.z)) }
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)

    for i = #list, limit + 1, -1 do list[i] = nil end

    return list
end

CreateThread(function()
    local reach = math.ceil(Config.RenderDistance / CELL)
    local despawnAt = Config.RenderDistance + 15.0

    while true do
        local origin = GetFinalRenderedCamCoord()
        local cx, cy = math.floor(origin.x / CELL), math.floor(origin.y / CELL)

        for id, entity in pairs(world.spawned) do
            local prop = world.props[id]

            if not world.locked[id] then
                if not prop or not DoesEntityExist(entity) or not visible(prop)
                    or #(origin - vector3(prop.x, prop.y, prop.z)) > despawnAt then
                    world.despawn(id)
                end
            end
        end

        for x = cx - reach, cx + reach do
            for y = cy - reach, cy + reach do
                local cell = cells[('%d:%d'):format(x, y)]

                if cell then
                    for id in pairs(cell) do
                        local prop = world.props[id]

                        if prop and not world.spawned[id] and visible(prop)
                            and #(origin - vector3(prop.x, prop.y, prop.z)) <= Config.RenderDistance then
                            spawn(prop)
                        end
                    end
                end
            end
        end

        Wait(world.builder and 250 or 1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(world.spawned) do world.despawn(id) end
    for id in pairs(world.hides) do world.unhide(id) end
end)

return world
