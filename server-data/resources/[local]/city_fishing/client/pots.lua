-- Crab pot buoys: local props spawned only near the player (lib.points), each with an ox_target "Pull" option.
-- The list comes from the server once and then as changes.
local water = require 'client.water'

local BUOY = `prop_dock_float_1b`
local SHOW_DISTANCE = 80.0
local PLACE_DISTANCE = 3.0

---@type table<integer, { data: table, point: table, prop: integer? }>
local pots = {}

local function removeProp(pot)
    if not pot.prop then return end

    exports.ox_target:removeLocalEntity(pot.prop)
    DeleteEntity(pot.prop)
    pot.prop = nil
end

local function pull(id)
    if lib.progressCircle({ duration = 4000, label = locale('pot_pulling'), useWhileDead = false, canCancel = true, disable = { move = true, combat = true } }) then
        local ok, result = lib.callback.await('city_fishing:pullPot', false, id)

        if not ok then
            return lib.notify({ description = locale(result or 'invalid'), type = 'error' })
        end

        if result.ready then
            lib.notify({ description = locale('pot_pulled', result.label), type = 'success' })
        else
            lib.notify({ description = locale(result.mine and 'pot_pulled_empty' or 'pot_taken'), type = 'inform' })
        end
    end
end

local function spawnProp(pot)
    if pot.prop then return end

    lib.requestModel(BUOY)

    local coords = pot.data.coords
    local prop = CreateObject(BUOY, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(BUOY)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, false)

    exports.ox_target:addLocalEntity(prop, {
        {
            name = 'city_fishing:pot',
            icon = 'fa-solid fa-box-open',
            label = locale('target_pot', pot.data.owner),
            distance = 4.0,
            onSelect = function() pull(pot.data.id) end,
        },
    })

    pot.prop = prop
end

local function add(data)
    if type(data) ~= 'table' or type(data.id) ~= 'number' then return end

    local existing = pots[data.id]
    if existing then
        removeProp(existing)
        existing.point:remove()
    end

    local pot = { data = data }
    pot.point = lib.points.new({
        coords = vec3(data.coords.x, data.coords.y, data.coords.z),
        distance = SHOW_DISTANCE,
        onEnter = function() spawnProp(pot) end,
        onExit = function() removeProp(pot) end,
    })

    pots[data.id] = pot
end

local function remove(id)
    local pot = pots[id]
    if not pot then return end

    removeProp(pot)
    pot.point:remove()
    pots[id] = nil
end

RegisterNetEvent('city_fishing:client:potAdded', function(data)
    if GetInvokingResource() then return end
    add(data)
end)

RegisterNetEvent('city_fishing:client:potRemoved', function(id)
    if GetInvokingResource() then return end
    remove(id)
end)

RegisterNetEvent('city_fishing:client:placePot', function()
    if GetInvokingResource() then return end

    local point = water.ahead(PLACE_DISTANCE)
    if not point then return lib.notify({ description = locale('pot_no_water'), type = 'error' }) end

    if not lib.progressCircle({ duration = 3000, label = locale('pot_placing'), canCancel = true, disable = { move = true, combat = true } }) then return end

    local ok, reason = lib.callback.await('city_fishing:placePot', false, { x = point.x, y = point.y, z = point.z })
    lib.notify({ description = locale(ok and 'pot_placed' or (reason or 'invalid')), type = ok and 'success' or 'error' })
end)

local function load()
    for id in pairs(pots) do remove(id) end

    for _, data in ipairs(lib.callback.await('city_fishing:pots', false) or {}) do add(data) end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', load)

AddEventHandler('onResourceStart', function(resource)
    if resource == cache.resource and LocalPlayer.state.isLoggedIn then load() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(pots) do remove(id) end
end)
