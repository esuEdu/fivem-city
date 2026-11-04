-- Bags on the ground for the drops the server tells us about. A bag only exists while the player is near it.

local SPAWN_DISTANCE = 50.0

---@type table<string, { point: CPoint, object?: integer }>
local drops = {}

---@param drop { object?: integer }
---@param coords vector3
local function spawnBag(drop, coords)
    lib.requestModel(Config.DropModel)

    local object = CreateObject(Config.DropModel, coords.x, coords.y, coords.z - 0.95, false, false, false)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, true)
    SetModelAsNoLongerNeeded(Config.DropModel)

    drop.object = object
end

---@param drop { object?: integer }
local function deleteBag(drop)
    if drop.object and DoesEntityExist(drop.object) then DeleteEntity(drop.object) end
    drop.object = nil
end

---@param id string
---@param coords vector3
local function addDrop(id, coords)
    if drops[id] then return end

    local drop = {}

    drop.point = lib.points.new({
        coords = coords,
        distance = SPAWN_DISTANCE,
        onEnter = function() spawnBag(drop, coords) end,
        onExit = function() deleteBag(drop) end,
    })

    drops[id] = drop
end

---@param id string
local function removeDrop(id)
    local drop = drops[id]
    if not drop then return end

    drop.point:remove()
    deleteBag(drop)
    drops[id] = nil
end

RegisterNetEvent('city_inventory:client:addDrop', addDrop)
RegisterNetEvent('city_inventory:client:removeDrop', removeDrop)

-- Drops made before this client (or this resource) started
CreateThread(function()
    for id, coords in pairs(lib.callback.await('city_inventory:getDrops', false) or {}) do
        addDrop(id, coords)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(drops) do removeDrop(id) end
end)
