-- Pick spots: props (or zones, indoors) appear while the player is near a field, minus the ones GlobalState says are picked
local util = require 'client.util'
local spots = require 'shared.spots'

local FIELD_DISTANCE = 80.0

---@type table<string, table<integer, { prop?: integer, zone?: integer }>> field -> spot index -> its prop or zone
local props = {}
local points = {}

local function isPicked(fieldId, index)
    local picked = GlobalState.cityDrugsPicked

    return picked ~= nil and picked[spots.key(fieldId, index)] == true
end

local function pick(fieldId, index)
    local field = Config.Fields[fieldId]

    local ok, amount = util.timed('city_drugs:startPick', 'city_drugs:pick', { fieldId, index }, {
        seconds = field.seconds,
        label = locale('picking'),
        scenario = field.scenario,
        anim = field.anim,
    })

    if ok then exports.qbx_core:Notify(locale('got', amount, util.label(field.item)), 'success') end
end

local function pickOption(fieldId, index)
    local field = Config.Fields[fieldId]

    return {
        name = 'city_drugs:pick',
        label = locale('target_pick', field.label),
        icon = field.icon,
        distance = Config.UseDistance,
        canInteract = function() return not cache.vehicle and not util.busy() end,
        onSelect = function() pick(fieldId, index) end,
    }
end

---A prop on the ground, or a target zone when the spot is part of the interior (no model)
local function spawnProp(fieldId, index, position)
    local field = Config.Fields[fieldId]

    if not field.model then
        local zone = exports.ox_target:addSphereZone({
            coords = vec3(position.x, position.y, position.z),
            radius = Config.StationRadius,
            options = { pickOption(fieldId, index) },
        })

        props[fieldId][index] = { zone = zone }
        return
    end

    lib.requestModel(field.model)

    local prop = CreateObject(field.model, position.x, position.y, position.z, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(field.model)

    exports.ox_target:addLocalEntity(prop, { pickOption(fieldId, index) })

    props[fieldId][index] = { prop = prop }
end

local function removeProp(fieldId, index)
    local spot = props[fieldId] and props[fieldId][index]
    if not spot then return end

    if spot.zone then
        exports.ox_target:removeZone(spot.zone)
    else
        exports.ox_target:removeLocalEntity(spot.prop)
        if DoesEntityExist(spot.prop) then DeleteEntity(spot.prop) end
    end

    props[fieldId][index] = nil
end

---Spawns or removes props so a loaded field matches what is picked
local function sync(fieldId)
    if not props[fieldId] then return end

    for index, position in ipairs(spots.list(Config.Fields[fieldId])) do
        local picked = isPicked(fieldId, index)

        if picked and props[fieldId][index] then
            removeProp(fieldId, index)
        elseif not picked and not props[fieldId][index] then
            spawnProp(fieldId, index, position)
        end
    end
end

local function unload(fieldId)
    if not props[fieldId] then return end

    for index in pairs(props[fieldId]) do removeProp(fieldId, index) end
    props[fieldId] = nil
end

for fieldId, field in pairs(Config.Fields) do
    points[#points + 1] = lib.points.new({
        coords = field.center,
        distance = FIELD_DISTANCE,
        onEnter = function()
            props[fieldId] = {}
            sync(fieldId)
        end,
        onExit = function() unload(fieldId) end,
    })
end

AddStateBagChangeHandler('cityDrugsPicked', 'global', function()
    -- GlobalState holds the new value only after the handler returns
    SetTimeout(0, function()
        for fieldId in pairs(props) do sync(fieldId) end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for fieldId in pairs(props) do unload(fieldId) end
    for i = 1, #points do points[i]:remove() end
end)
