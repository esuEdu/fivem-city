-- Cash bags on the floor, from GlobalState.robberyBags: a local prop with an ox_target option, only while near
local bag = Config.Bag

-- id -> { point, object, zone }
local shown = {}

local function deleteObject(entry)
    if entry.zone then exports.ox_target:removeZone(entry.zone) end
    if entry.object and DoesEntityExist(entry.object) then DeleteEntity(entry.object) end

    entry.object = nil
    entry.zone = nil
end

local function pickUp(id)
    if not lib.progressBar({
        duration = 1200,
        label = locale('picking_up'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'pickup_object', clip = 'pickup_low' },
    }) then return end

    local ok, result = lib.callback.await('city_robbery:pickBag', false, tonumber(id))
    if ok then
        lib.notify({ description = locale('picked_up', result), type = 'success' })
    else
        lib.notify({ description = locale(result or 'failed'), type = 'error' })
    end
end

local function spawnObject(id, entry, coords)
    lib.requestModel(bag.model)

    local object = CreateObject(bag.model, coords.x, coords.y, coords.z - 0.9, false, false, false)
    SetModelAsNoLongerNeeded(bag.model)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)

    entry.object = object

    -- A zone round the bag rather than the entity: ox_target's ray misses a small prop on the floor
    entry.zone = exports.ox_target:addSphereZone({
        coords = GetEntityCoords(object) + vec3(0.0, 0.0, 0.2),
        radius = bag.targetRadius,
        options = {
            {
                name = 'city_robbery:bag',
                label = locale('pick_bag'),
                icon = 'fas fa-sack-dollar',
                distance = bag.pickDistance,
                onSelect = function() pickUp(id) end,
            },
        },
    })
end

local function remove(id)
    local entry = shown[id]
    if not entry then return end

    entry.point:remove()
    deleteObject(entry)
    shown[id] = nil
end

local function sync(list)
    list = type(list) == 'table' and list or {}

    for id in pairs(shown) do
        if not list[id] then remove(id) end
    end

    for id, coords in pairs(list) do
        if not shown[id] then
            local entry = {}

            entry.point = lib.points.new({
                coords = vec3(coords.x, coords.y, coords.z),
                distance = bag.spawnDistance,
                onEnter = function() spawnObject(id, entry, coords) end,
                onExit = function() deleteObject(entry) end,
            })

            shown[id] = entry
        end
    end
end

AddStateBagChangeHandler('robberyBags', 'global', function(_, _, value)
    sync(value)
end)

CreateThread(function()
    sync(GlobalState.robberyBags)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(shown) do remove(id) end
end)
