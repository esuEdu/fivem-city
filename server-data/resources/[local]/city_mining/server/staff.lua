-- /miningpoints: staff place and remove the points where veins, gravel and the passage blocker can be. Every callback
-- checks the ACE again; changes go to the staff log.
local points = require 'server.points'
local veins = require 'server.veins'
local util = require 'server.util'

local ACE = 'group.admin'
local RANGE = 200.0

---@param src integer
---@return boolean
local function allowed(src)
    return IsPlayerAceAllowed(tostring(src), ACE) and exports.qbx_core:IsOptin(src)
end

---@param src integer
---@param action string
---@param detail string
local function log(src, action, detail)
    if GetResourceState('city_staff') == 'started' then
        exports.city_staff:Log(src, action, nil, detail)
    end
end

local function publishAreas()
    GlobalState.miningAreas = points.publicAreas()
end

lib.addCommand('miningpoints', {
    help = locale('command_points'),
    restricted = ACE,
}, function(source)
    if source == 0 then return lib.print.info('city_mining: /miningpoints is used in game') end
    if not exports.qbx_core:IsOptin(source) then return util.notify(source, 'not_on_duty', 'error') end

    local regions = {}
    for _, region in ipairs(Config.Regions) do regions[#regions + 1] = { id = region.id, label = region.label, kind = region.kind } end

    TriggerClientEvent('city_mining:client:pointsTool', source, regions)
end)

lib.callback.register('city_mining:staff:points', function(source)
    local src = source
    if not allowed(src) then return false end

    local origin = GetEntityCoords(GetPlayerPed(src))
    local list = {}

    for id, point in pairs(points.byId) do
        if #(point.coords.xyz - origin) <= RANGE then
            list[#list + 1] = { id = id, region = point.region, kind = point.kind, x = point.coords.x, y = point.coords.y, z = point.coords.z }
        end
    end

    return true, list
end)

lib.callback.register('city_mining:staff:add', function(source, region, kind, coords)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid or not allowed(src) then
        lib.print.warn(('city_mining: %s tried to add a point without permission'):format(src))
        return false, 'no_permission'
    end

    local x, y, z, h = type(coords) == 'table' and tonumber(coords.x), type(coords) == 'table' and tonumber(coords.y),
        type(coords) == 'table' and tonumber(coords.z), type(coords) == 'table' and tonumber(coords.w) or 0.0
    if not x or not y or not z then return false, 'invalid' end

    local at = vec3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - at) > 30.0 then return false, 'too_far' end

    local point = points.add(region, kind, vec4(x, y, z, h), citizenid)
    if not point then return false, 'invalid' end

    publishAreas()
    veins.fill()
    log(src, 'mining_point_add', ('%s %s #%d'):format(region, kind, point.id))

    return true, point.id
end)

lib.callback.register('city_mining:staff:remove', function(source, id)
    local src = source
    if not util.player(src) or not allowed(src) then return false, 'no_permission' end

    id = math.tointeger(id)
    local point = id and points.byId[id]
    if not point then return false, 'invalid' end
    if #(GetEntityCoords(GetPlayerPed(src)) - point.coords.xyz) > 30.0 then return false, 'too_far' end

    points.remove(id)
    veins.forget(point)
    publishAreas()
    log(src, 'mining_point_remove', ('%s %s #%d'):format(point.region, point.kind, id))

    return true
end)
