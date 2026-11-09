-- Players who already picked a spawn for the character they are on
local spawned = {}

local byId = {}
for i = 1, #Config.Spots do
    byId[Config.Spots[i].id] = Config.Spots[i]
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---Where the character logged out, or nil when it was never saved or is a bad save
local function lastPosition(player)
    local pos = player.PlayerData.position
    if type(pos) ~= 'table' and type(pos) ~= 'vector3' and type(pos) ~= 'vector4' then return end

    local x, y, z = pos.x, pos.y, pos.z
    local w = type(pos) ~= 'vector3' and pos.w or 0.0
    if not finite(x) or not finite(y) or not finite(z) then return end

    -- A save without a ped stores the map origin
    if math.abs(x) < 5 and math.abs(y) < 5 then return end

    return vec4(x, y, z, finite(w) and w or 0.0)
end

---Characters that logged out jailed, down or cuffed go back where they were (the prison and medical scripts take over)
local function mustStayPut(player)
    local meta = player.PlayerData.metadata
    return (tonumber(meta.injail) or 0) > 0 or meta.isdead or meta.inlaststand or meta.ishandcuffed or false
end

local function propertyOf(player)
    if GetResourceState('qbx_properties') ~= 'started' then return end
    return player.PlayerData.metadata.currentPropertyId
end

lib.callback.register('city_spawn:open', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or spawned[src] then return end

    if mustStayPut(player) then return { forced = true } end

    local last = lastPosition(player)
    local list = {}

    for i = 1, #Config.Spots do
        local spot = Config.Spots[i]
        local coords = spot.last and last or spot.coords

        if coords then
            list[#list + 1] = { id = spot.id, label = spot.label, icon = spot.icon, color = spot.color, coords = coords }
        end
    end

    return { spots = list }
end)

lib.callback.register('city_spawn:choose', function(source, id)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or spawned[src] then return end

    local spot = type(id) == 'string' and byId[id]
    if not spot then
        lib.print.warn(('city_spawn: player %s sent an unknown spot: %s'):format(src, tostring(id)))
        return
    end

    spawned[src] = true

    if spot.last or mustStayPut(player) then
        return lastPosition(player) or Config.Fallback, propertyOf(player)
    end

    return spot.coords
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    spawned[src] = nil
end)

AddEventHandler('playerDropped', function()
    spawned[source] = nil
end)
