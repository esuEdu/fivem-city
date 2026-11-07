-- Props officers place (cones, barriers...) and spike strips. Spawned on the server; spike positions go in
-- GlobalState.policeSpikes because every driver's client checks its own tyres against them.

local police = require 'server.police'

---@type table<integer, { owner: integer, spike: boolean }> entity -> who placed it
local placed = {}
local MAX_DISTANCE = 6.0

---@param owner integer
---@param spike boolean
---@return integer
local function countOf(owner, spike)
    local count = 0

    for _, entry in pairs(placed) do
        if entry.owner == owner and entry.spike == spike then count = count + 1 end
    end

    return count
end

local function syncSpikes()
    local list = {}

    for entity, entry in pairs(placed) do
        if entry.spike and DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            list[#list + 1] = { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(entity) }
        end
    end

    GlobalState.policeSpikes = list
end

---@param src integer
---@param coords unknown
---@return vector3?
local function placeCoords(src, coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    local point = vec3(x, y, z)
    if not police.near(src, point, MAX_DISTANCE) then return end

    return point
end

lib.callback.register('city_police:placeObject', function(source, kind, coords, heading)
    local src = source
    if not police.onDuty(src) then return false end

    local spike = kind == 'spike'
    local object = Config.Objects[kind]
    if not spike and not object then return false end

    local point = placeCoords(src, coords)
    if not point or type(heading) ~= 'number' then return false end

    if countOf(src, spike) >= (spike and Config.MaxSpikes or Config.MaxObjects) then return false, 'too_many' end

    local entity = CreateObjectNoOffset(spike and Config.SpikeModel or object.model, point.x, point.y, point.z, true, true, false)
    local timeout = GetGameTimer() + 3000
    while not DoesEntityExist(entity) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(entity) then return false end

    SetEntityHeading(entity, heading + 0.0)
    FreezeEntityPosition(entity, spike or object.freeze)
    Entity(entity).state:set('policeObject', true, true)

    placed[entity] = { owner = src, spike = spike }
    if spike then syncSpikes() end

    return true, NetworkGetNetworkIdFromEntity(entity)
end)

lib.callback.register('city_police:removeObject', function(source, netId)
    local src = source
    if not police.onDuty(src) or type(netId) ~= 'number' then return false end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local entry = entity and placed[entity]
    if not entry or not DoesEntityExist(entity) then return false end
    if not police.near(src, GetEntityCoords(entity), MAX_DISTANCE) then return false end

    DeleteEntity(entity)
    placed[entity] = nil
    if entry.spike then syncSpikes() end

    return true
end)

-- Spike strips go when the officer who laid them goes off duty (or leaves); cones and barriers stay
AddEventHandler('city_police:server:offDuty', function(src)
    local spikes = false

    for entity, entry in pairs(placed) do
        if entry.owner == src and entry.spike then
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            placed[entity] = nil
            spikes = true
        end
    end

    if spikes then syncSpikes() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for entity in pairs(placed) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end

    GlobalState.policeSpikes = nil
end)

GlobalState.policeSpikes = {}
