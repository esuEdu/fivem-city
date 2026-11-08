-- The Builder: registers the tablet app, sends the placed world to every client and runs the editor's changes.
-- Every change checks the ACE + admin duty, the arguments and the distance again, and goes to the staff log.
local validate = require 'shared.validate'
local store = require 'server.store'
local streams = require 'server.streams'

local ready = false
local rates = {}

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/app/index.html',
        icon = Config.App.icon,
        access = { staff = Config.Ace },
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

MySQL.ready(function()
    store.load()
    ready = true
    TriggerClientEvent('city_builder:client:world', -1, store.snapshot())
end)

CreateThread(streams.scan)

---@return boolean
local function isBuilder(src)
    return IsPlayerAceAllowed(tostring(src), Config.Ace) and exports.qbx_core:IsOptin(src) == true
end

---@return boolean
local function rateLimited(src)
    local now = GetGameTimer()
    local rate = rates[src]

    if not rate or now - rate.from >= 1000 then
        rates[src] = { from = now, count = 1 }
        return false
    end

    rate.count = rate.count + 1

    return rate.count > Config.OpsPerSecond
end

---The point is within freecam reach of the builder's character.
local function inReach(src, x, y, z)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end

    return #(GetEntityCoords(ped) - vector3(x, y, z)) <= Config.MaxCamDistance + 25.0
end

local function log(src, action, details)
    pcall(function()
        exports.city_staff:Log(src, action, nil, details)
    end)
end

local function propText(prop)
    return ('#%d %s at %.2f, %.2f, %.2f'):format(prop.id, prop.model, prop.x, prop.y, prop.z)
end

local function groupId(value)
    value = math.tointeger(value)

    return value and store.groups[value] and value or nil
end

local actions = {}

function actions.start()
    return true, { models = streams.models, count = store.count, max = Config.MaxProps }
end

function actions.create(src, by, data)
    if store.count >= Config.MaxProps then return false, 'limit' end

    local prop, reason = validate.prop(data)
    if not prop then return false, reason end
    if not inReach(src, prop.x, prop.y, prop.z) then return false, 'far' end

    prop.group = groupId(prop.group)

    local saved = store.create(prop, by)
    if not saved then return false, 'failed' end

    TriggerClientEvent('city_builder:client:props', -1, { saved })
    log(src, 'builder_create', propText(saved))

    return true, saved
end

function actions.update(src, by, data)
    local id = type(data) == 'table' and math.tointeger(data.id)
    local current = id and store.props[id]
    if not current then return false, 'unknown' end

    local prop, reason = validate.prop(data)
    if not prop then return false, reason end
    if not inReach(src, prop.x, prop.y, prop.z) and not inReach(src, current.x, current.y, current.z) then return false, 'far' end

    prop.group = groupId(prop.group)

    local saved = store.update(id, prop, by)
    if not saved then return false, 'failed' end

    TriggerClientEvent('city_builder:client:props', -1, { saved })
    log(src, 'builder_update', propText(saved))

    return true, saved
end

function actions.delete(src, _, id)
    id = math.tointeger(id)
    if not id or not store.props[id] then return false, 'unknown' end

    local deleted = store.delete(id)
    if not deleted then return false, 'failed' end

    TriggerClientEvent('city_builder:client:removeProps', -1, { id })
    log(src, 'builder_delete', propText(deleted))

    return true, deleted
end

function actions.hide(src, by, data)
    local hide, reason = validate.hide(data)
    if not hide then return false, reason end
    if not inReach(src, hide.x, hide.y, hide.z) then return false, 'far' end

    local saved = store.createHide(hide, Config.HideRadius, by)
    if not saved then return false, 'failed' end

    TriggerClientEvent('city_builder:client:hide', -1, saved)
    log(src, 'builder_hide', ('#%d %s at %.2f, %.2f, %.2f'):format(saved.id, saved.label, saved.x, saved.y, saved.z))

    return true, saved
end

function actions.unhide(src, _, id)
    id = math.tointeger(id)
    local hide = id and store.deleteHide(id)
    if not hide then return false, 'unknown' end

    TriggerClientEvent('city_builder:client:unhide', -1, id)
    log(src, 'builder_unhide', ('#%d %s'):format(id, hide.label))

    return true, hide
end

function actions.groupCreate(src, by, name)
    name = validate.groupName(name)
    if not name then return false, 'name' end

    local total = 0
    for _ in pairs(store.groups) do total = total + 1 end
    if total >= Config.MaxGroups then return false, 'limit' end

    local group = store.createGroup(name, by)
    if not group then return false, 'failed' end

    TriggerClientEvent('city_builder:client:groups', -1, { group })
    log(src, 'builder_group', ('created #%d %s'):format(group.id, name))

    return true, group
end

function actions.groupUpdate(src, _, data)
    local id = type(data) == 'table' and groupId(data.id)
    if not id then return false, 'unknown' end

    local name = validate.groupName(data.name)
    if not name then return false, 'name' end

    local group = store.updateGroup(id, name, data.enabled ~= false)
    if not group then return false, 'failed' end

    TriggerClientEvent('city_builder:client:groups', -1, { group })
    log(src, 'builder_group', ('#%d %s %s'):format(id, name, group.enabled and 'shown' or 'hidden'))

    return true, group
end

function actions.groupDelete(src, _, id)
    id = groupId(id)
    if not id then return false, 'unknown' end

    local name = store.groups[id].name
    local ids = store.deleteGroup(id)
    if not ids then return false, 'failed' end

    if #ids > 0 then TriggerClientEvent('city_builder:client:removeProps', -1, ids) end
    TriggerClientEvent('city_builder:client:removeGroup', -1, id)
    log(src, 'builder_group', ('deleted #%d %s with %d props'):format(id, name, #ids))

    return true, #ids
end

function actions.groupMove(src, by, data)
    local id = type(data) == 'table' and groupId(data.id)
    if not id then return false, 'unknown' end

    local dx, dy, dz = validate.offset(data, Config.MaxGroupOffset)
    if not dx then return false, 'offset' end

    for _, prop in pairs(store.props) do
        if prop.group == id and not validate.inMap(prop.x + dx, prop.y + dy, prop.z + dz) then return false, 'coords' end
    end

    local moved = store.moveGroup(id, dx, dy, dz, by)
    if not moved then return false, 'failed' end

    if #moved > 0 then TriggerClientEvent('city_builder:client:props', -1, moved) end
    log(src, 'builder_group', ('moved #%d by %.2f, %.2f, %.2f'):format(id, dx, dy, dz))

    return true, #moved
end

lib.callback.register('city_builder:world', function()
    if not ready then return false end

    return store.snapshot()
end)

lib.callback.register('city_builder:op', function(source, action, args)
    local src = source
    local handler = type(action) == 'string' and actions[action]
    if not handler then return false, 'invalid' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'invalid' end

    if not isBuilder(src) then
        lib.print.warn(('city_builder: %s (%d) tried %s without access'):format(GetPlayerName(src), src, action))
        return false, 'no_access'
    end

    if not ready then return false, 'loading' end
    if action ~= 'start' and rateLimited(src) then return false, 'slow_down' end

    return handler(src, player.PlayerData.citizenid, args)
end)

AddEventHandler('playerDropped', function()
    rates[source] = nil
end)
