-- Boat rental at the marina: a fee plus a deposit, refunded when the boat comes back to a marina in one piece.
-- One rental per character; the boat is deleted when its renter leaves (deposit refunded if the boat was still whole).
local settings = require 'server.config'
local util = require 'server.util'

local MARINA_RANGE = 4.0

---@type table<string, { vehicle: integer, src: integer }>
local rentals = {}

---@param src integer
---@return table? marina
local function marinaNear(src, range)
    for _, marina in ipairs(Config.Marinas) do
        if util.near(src, marina.coords, range) then return marina end
    end
end

---@param citizenid string
---@param refund boolean
local function finish(citizenid, refund)
    local rental = rentals[citizenid]
    if not rental then return end

    rentals[citizenid] = nil

    local whole = DoesEntityExist(rental.vehicle) and GetVehicleEngineHealth(rental.vehicle) > 0
    if DoesEntityExist(rental.vehicle) then DeleteEntity(rental.vehicle) end

    if refund and whole and GetPlayerName(rental.src) then
        exports.qbx_core:AddMoney(rental.src, 'cash', settings.boat.deposit, 'fishing-boat-refund')
    end

    return whole
end

lib.callback.register('city_fishing:rentBoat', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local marina = marinaNear(src, MARINA_RANGE)
    if not marina then return false, 'too_far' end
    if rentals[citizenid] then return false, 'boat_already' end

    local total = settings.boat.fee + settings.boat.deposit
    if exports.qbx_core:GetMoney(src, 'cash') < total and exports.qbx_core:GetMoney(src, 'bank') < total then return false, 'no_money' end
    if not util.pay(src, settings.boat.fee, 'fishing-boat-rent') then return false, 'no_money' end

    if not util.pay(src, settings.boat.deposit, 'fishing-boat-deposit') then
        exports.qbx_core:AddMoney(src, 'cash', settings.boat.fee, 'fishing-boat-refund')
        return false, 'no_money'
    end

    rentals[citizenid] = { vehicle = 0, src = src }

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, {
        spawnSource = marina.spawn,
        model = settings.boat.model,
        warp = GetPlayerPed(src),
        props = { plate = ('FISH%04d'):format(math.random(0, 9999)), fuelLevel = 100.0 },
    })

    if not ok or not netId or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        if not ok then lib.print.error(netId) end
        rentals[citizenid] = nil
        exports.qbx_core:AddMoney(src, 'cash', total, 'fishing-boat-refund')
        return false, 'boat_failed'
    end

    rentals[citizenid] = { vehicle = vehicle, src = src }
    Entity(vehicle).state:set('fishingRental', true, true)

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
    end

    return true
end)

lib.callback.register('city_fishing:returnBoat', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local rental = rentals[citizenid]
    if not rental then return false, 'no_boat' end

    local near = false
    for _, marina in ipairs(Config.Marinas) do
        if DoesEntityExist(rental.vehicle) and #(GetEntityCoords(rental.vehicle) - marina.coords.xyz) <= marina.returnRadius then
            near = true
        end
    end

    if DoesEntityExist(rental.vehicle) and not near then return false, 'boat_far' end
    if not marinaNear(src, MARINA_RANGE) then return false, 'too_far' end

    return true, finish(citizenid, true) == true
end)

lib.callback.register('city_fishing:boatInfo', function(source)
    local _, citizenid = util.player(source)
    if not citizenid then return false end

    return true, { renting = rentals[citizenid] ~= nil, fee = settings.boat.fee, deposit = settings.boat.deposit }
end)

AddEventHandler('playerDropped', function()
    local src = source

    for citizenid, rental in pairs(rentals) do
        if rental.src == src then finish(citizenid, false) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, rental in pairs(rentals) do
        if DoesEntityExist(rental.vehicle) then DeleteEntity(rental.vehicle) end
    end
end)
