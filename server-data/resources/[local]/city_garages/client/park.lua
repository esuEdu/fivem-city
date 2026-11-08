-- "Park vehicle" on any car while the player is inside a garage's parking area (lib.points around the ped and
-- spawn points). The server decides whether the car is theirs and which garage takes it.

local nearby = {} -- garage id -> { garage, count of parking points the player is inside }
local points = {} -- garage id -> lib.points

---@param vehicle integer
---@return string
local function kindOf(vehicle)
    return Config.ClassKinds[GetVehicleClass(vehicle)] or 'car'
end

---@param vehicle integer
---@return boolean
local function canPark(vehicle)
    if cache.vehicle or not next(nearby) then return false end

    local kind = kindOf(vehicle)

    for _, entry in pairs(nearby) do
        local garage = entry.garage
        if garage.kind == kind and (not garage.groups or exports.qbx_core:HasPrimaryGroup(garage.groups)) then return true end
    end

    return false
end

---@param vehicle integer
local function park(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local parked, result = lib.callback.await('city_garages:park', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle))

    if parked then
        exports.qbx_core:Notify(locale('parked', result), 'success')
    else
        exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
    end
end

---@param garage table
---@param coords vector3
---@return table
local function point(garage, coords)
    return lib.points.new({
        coords = coords,
        distance = Config.ParkRadius,
        onEnter = function()
            local entry = nearby[garage.id] or { garage = garage, count = 0 }
            entry.count = entry.count + 1
            nearby[garage.id] = entry
        end,
        onExit = function()
            local entry = nearby[garage.id]
            if not entry then return end

            entry.count = entry.count - 1
            if entry.count <= 0 then nearby[garage.id] = nil end
        end,
    })
end

local M = {}

---@param garage table
function M.add(garage)
    local list = { point(garage, garage.coords.xyz) }

    for i = 1, #garage.spawns do
        list[#list + 1] = point(garage, garage.spawns[i].xyz)
    end

    points[garage.id] = list
end

---@param id string
function M.remove(id)
    for _, entry in ipairs(points[id] or {}) do
        entry:remove()
    end

    points[id], nearby[id] = nil, nil
end

exports.ox_target:addGlobalVehicle({
    name = 'city_garages:park',
    label = locale('target_park'),
    icon = 'fas fa-square-parking',
    distance = 3.0,
    canInteract = canPark,
    onSelect = function(data)
        CreateThread(function() park(data.entity) end)
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalVehicle('city_garages:park')
end)

return M
