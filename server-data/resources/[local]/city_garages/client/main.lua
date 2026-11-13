local theme = require '@city_ui.theme'
local park = require 'client.park'

local garages = {}
local blips = {}
local points = {}
local peds = {}
local icons = {}
local current
local currentLot

---@param garage table
---@return boolean
local function allowed(garage)
    return not garage.groups or exports.qbx_core:HasPrimaryGroup(garage.groups)
end

-- Favorites are a per-player convenience, kept on this machine
local function loadFavorites()
    local ok, list = pcall(json.decode, GetResourceKvpString('favorites') or '[]')

    return ok and type(list) == 'table' and list or {}
end

local function saveFavorite(id, on)
    local list = loadFavorites()
    local kept = {}

    for i = 1, #list do
        if list[i] ~= id then kept[#kept + 1] = list[i] end
    end

    if on then kept[#kept + 1] = id end
    SetResourceKvp('favorites', json.encode(kept))
end

local function close()
    if not current then return end

    current, currentLot = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- The impound lot of this kind closest to the player, for cars that wait there
---@param kind string
---@return table?
local function nearestDepot(kind)
    local best, bestDistance

    for _, garage in pairs(garages) do
        if garage.depot and garage.kind == kind and allowed(garage) then
            local distance = #(cache.coords - garage.coords.xyz)

            if not best or distance < bestDistance then best, bestDistance = garage, distance end
        end
    end

    return best
end

---@param garage table
local function open(garage)
    if current then return end

    if not allowed(garage) then
        return exports.qbx_core:Notify(locale('error_no_access'), 'error')
    end

    local vehicles = lib.callback.await('city_garages:getVehicles', false, garage.id)
    if not vehicles then return exports.qbx_core:Notify(locale('error_no_access'), 'error') end
    if #vehicles == 0 then return exports.qbx_core:Notify(locale('no_vehicles'), 'inform') end

    local lot = not garage.depot and nearestDepot(garage.kind) or nil

    current = garage
    currentLot = lot
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        garage = { label = garage.label, depot = garage.depot, lot = lot and lot.label or nil },
        vehicles = vehicles,
        favorites = loadFavorites(),
    })
end

-- The car icon over the garage keeper (or the garage point), used with E
---@param garage table
---@return integer?
local function addIcon(garage)
    return exports.city_points:Add({
        coords = garage.coords.xyz,
        ped = garage.ped and true or false,
        icon = 'car',
        label = locale(garage.depot and 'target_depot' or 'target_garage'),
        canInteract = function()
            return allowed(garage)
        end,
        onUse = function()
            CreateThread(function() open(garage) end)
        end,
    })
end

---@param garage table
local function spawnPed(garage)
    if peds[garage.id] then return end

    local coords = garage.coords
    lib.requestModel(Config.Ped)

    local ped = CreatePed(4, Config.Ped, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetModelAsNoLongerNeeded(Config.Ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)

    peds[garage.id] = ped
end

---@param id string
local function removePed(id)
    local ped = peds[id]
    if not ped then return end

    DeleteEntity(ped)
    peds[id] = nil
end

---@param garage table
local function addBlip(garage)
    if not garage.blip or garage.groups then return end

    local coords = garage.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, garage.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.6)
    SetBlipColour(blip, garage.blip.color or 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(garage.blip.name or garage.label)
    EndTextCommandSetBlipName(blip)
    blips[garage.id] = blip
end

---@param id string
local function removeGarage(id)
    removePed(id)
    park.remove(id)

    if blips[id] then RemoveBlip(blips[id]) end
    if points[id] then points[id]:remove() end
    if icons[id] then exports.city_points:Remove(icons[id]) end

    blips[id], points[id], icons[id], garages[id] = nil, nil, nil, nil
end

---@param garage table
local function addGarage(garage)
    removeGarage(garage.id)
    garages[garage.id] = garage
    addBlip(garage)

    if not garage.depot then park.add(garage) end

    icons[garage.id] = addIcon(garage)
    if not garage.ped then return end

    points[garage.id] = lib.points.new({
        coords = garage.coords.xyz,
        distance = Config.PedDistance,
        onEnter = function()
            spawnPed(garage)
        end,
        onExit = function()
            removePed(garage.id)
        end,
    })
end

RegisterNetEvent('city_garages:client:garageRegistered', function(garage)
    if type(garage) ~= 'table' or type(garage.id) ~= 'string' then return end

    addGarage(garage)
end)

RegisterNUICallback('ready', function(_, cb)
    local labels = {}

    for _, key in ipairs({
        'ui_search', 'ui_all', 'ui_favorites', 'ui_count', 'ui_empty', 'ui_select', 'ui_plate', 'ui_engine', 'ui_body',
        'ui_fuel', 'ui_fee', 'ui_take_out', 'ui_pay_take_out', 'ui_close', 'ui_depot', 'ui_garage', 'state_garaged',
        'state_street', 'state_depot', 'state_impounded', 'hint_street', 'hint_depot', 'hint_depot_at', 'hint_impounded',
        'hint_garaged', 'ui_route',
    }) do
        labels[key] = locale(key)
    end

    cb({ theme = theme, labels = labels })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

-- A car waiting at the impound lot: the GPS route there
RegisterNUICallback('route', function(_, cb)
    local lot = currentLot
    if not lot then return cb(false) end

    SetNewWaypoint(lot.coords.x, lot.coords.y)
    close()
    exports.qbx_core:Notify(locale('route_set', lot.label), 'inform')
    cb(true)
end)

RegisterNUICallback('favorite', function(data, cb)
    local id = math.tointeger(data and data.id)
    if id then saveFavorite(id, data.on == true) end
    cb(true)
end)

RegisterNUICallback('takeOut', function(data, cb)
    local garage = current
    local id = math.tointeger(data and data.id)
    if not garage or not id then return cb(false) end

    local netId, err = lib.callback.await('city_garages:takeOut', false, garage.id, id)

    if not netId then
        exports.qbx_core:Notify(locale(('error_%s'):format(err or 'failed')), 'error')
        return cb(false)
    end

    close()
    exports.qbx_core:Notify(locale('taken_out'), 'success')
    cb(true)
end)

CreateThread(function()
    local list = lib.callback.await('city_garages:getGarages', false)

    for _, garage in pairs(list or {}) do
        addGarage(garage)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    close()

    for id in pairs(garages) do
        removeGarage(id)
    end
end)
