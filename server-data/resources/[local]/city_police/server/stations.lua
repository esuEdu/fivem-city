-- Station places: clocking in, the armory, lockers, the evidence locker, trash and the garages.

local police = require 'server.police'
local roster = require 'server.roster'
local settings = require 'server.config'

---@type table<integer, integer> officer -> their job vehicle
local vehicles = {}

---@param key string station field
---@return vector3[]
local function placesOf(key)
    local list = {}

    for _, station in ipairs(Config.Stations) do
        if station[key] then list[#list + 1] = station[key] end
    end

    return list
end

---@param src integer
---@param key string
---@return boolean
local function atAny(src, key)
    for _, coords in ipairs(placesOf(key)) do
        if police.near(src, coords, Config.Ranges.place + 1.0) then return true end
    end

    return false
end

CreateThread(function()
    local groups = { [Config.Job] = 0 }

    exports.city_inventory:RegisterShop('CityPoliceArmory', {
        name = locale('armory'),
        inventory = settings.armory,
        groups = groups,
        locations = placesOf('armory'),
    })

    exports.city_inventory:RegisterStash('city_police_locker', locale('locker'), settings.locker.slots, settings.locker.weight, true, groups, placesOf('locker'))
    exports.city_inventory:RegisterStash('city_police_evidence', locale('evidence_locker'), settings.evidenceLocker.slots, settings.evidenceLocker.weight, nil, groups, placesOf('evidence'))
    exports.city_inventory:RegisterStash('city_police_trash', locale('trash'), settings.trash.slots, settings.trash.weight, nil, groups, placesOf('trash'))

    -- The trash empties on every restart
    exports.city_inventory:ClearInventory('city_police_trash')
end)

lib.callback.register('city_police:duty', function(source)
    local src = source
    if not police.isCop(src) or not atAny(src, 'duty') then return end

    local onDuty = not police.onDuty(src)
    exports.qbx_core:SetJobDuty(src, onDuty)

    return onDuty
end)

---@param src integer
---@param kind string 'car' | 'heli'
---@return table? garage the station garage the officer stands at
local function garageAt(src, kind)
    local key = kind == 'heli' and 'heli' or 'garage'

    for _, station in ipairs(Config.Stations) do
        local garage = station[key]
        if garage and police.near(src, garage.menu, Config.Ranges.place + 2.0) then return garage end
    end
end

-- Job vehicles: one per officer, from the garage they stand at, only models for their grade and certifications
lib.callback.register('city_police:spawnVehicle', function(source, kind, model)
    local src = source
    if not police.onDuty(src) or (kind ~= 'car' and kind ~= 'heli') or type(model) ~= 'string' then return end

    local garage = garageAt(src, kind)
    if not garage then return end

    local allowed
    for _, entry in ipairs(Config.Vehicles[kind]) do
        local certified = not entry.cert or not Config.Features.certs or roster.hasCert(src, entry.cert)

        if entry.model == model and police.grade(src) >= entry.grade and certified then
            allowed = entry
        end
    end

    if not allowed then return police.warn(src, ('asked for vehicle %s they may not take'):format(model)) end
    if vehicles[src] and DoesEntityExist(vehicles[src]) then return false, 'vehicle_out' end

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { spawnSource = garage.spawn, model = model, warp = GetPlayerPed(src) })
    if not ok or not netId or not vehicle or vehicle == 0 then return end

    vehicles[src] = vehicle
    SetVehicleNumberPlateText(vehicle, ('%s%04d'):format(Config.PlatePrefix, math.random(0, 9999)))
    exports.qbx_vehiclekeys:GiveKeys(src, vehicle)

    return netId
end)

lib.callback.register('city_police:storeVehicle', function(source)
    local src = source
    local vehicle = vehicles[src]

    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle)) > 15.0 then return false end

    DeleteEntity(vehicle)
    vehicles[src] = nil

    return true
end)

-- The garage menu greys out what the officer can't take
lib.callback.register('city_police:myCerts', function(source)
    local unit = roster.unit(source)
    return unit and unit.certs or {}
end)

AddEventHandler('playerDropped', function()
    local vehicle = vehicles[source]
    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    vehicles[source] = nil
end)
