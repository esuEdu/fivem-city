-- What officers do to a player in reach: cuff, escort, put in or take out of a vehicle, check status, ankle monitor.
-- The server decides and sets the state (metadata.ishandcuffed, escorts); the clients only play it.

local police = require 'server.police'
local status = require 'server.status'

---@type table<integer, { soft: boolean, by: integer, breakUntil: integer? }>
local cuffs = {}
---@type table<integer, integer> escorted -> officer
local escorts = {}

local MAX_STATUS_SECONDS = 600
local BREAK_SECONDS = 8

---@param src integer
---@return table?
local function metadata(src)
    local player = exports.qbx_core:GetPlayer(src)

    return player and player.PlayerData.metadata
end

---@param src integer
---@return boolean
local function isDown(src)
    local data = metadata(src)

    return data ~= nil and (data.isdead or data.inlaststand) == true
end

---@param target integer
---@return boolean
local function isCuffed(target)
    local data = metadata(target)

    return data ~= nil and data.ishandcuffed == true
end

---@param target integer
local function stopEscort(target)
    local officer = escorts[target]
    if not officer then return end

    escorts[target] = nil
    TriggerClientEvent('city_police:client:escorted', target, false)
    if GetPlayerName(officer) then TriggerClientEvent('city_police:client:escorting', officer, false) end
end

---Puts cuffs on or takes them off; the only place that writes metadata.ishandcuffed.
---@param target integer
---@param on boolean
---@param soft? boolean
---@param by? integer officer (0 for staff or scripts)
local function setCuffed(target, on, soft, by)
    exports.qbx_core:SetMetadata(target, 'ishandcuffed', on)
    Player(target).state:set('invBusy', on, true)

    if on then
        cuffs[target] = { soft = soft == true, by = by or 0, breakUntil = soft and os.time() + BREAK_SECONDS or nil }
    else
        cuffs[target] = nil
        stopEscort(target)
        Player(target).state:set('zipTied', nil, true)
    end

    TriggerClientEvent('city_police:client:cuffed', target, on, soft == true, by or 0)
end

lib.callback.register('city_police:cuff', function(source, target, soft)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target, Config.Ranges.cuff)
    if not target then return false, 'too_far' end

    if isCuffed(target) then
        setCuffed(target, false, false, src)
        return true, false
    end

    if exports.city_inventory:GetItemCount(src, 'handcuffs') < 1 then return false, 'no_cuffs' end
    if IsPedInAnyVehicle(GetPlayerPed(target), false) then return false, 'in_vehicle' end

    setCuffed(target, true, soft == true, src)

    return true, true
end)

-- A soft cuff can be broken right after it's put on (the client's skill check)
RegisterNetEvent('city_police:server:breakCuffs', function()
    local src = source
    local cuff = cuffs[src]

    if not cuff or not cuff.soft or not cuff.breakUntil or os.time() > cuff.breakUntil then
        return police.warn(src, 'tried to break cuffs they could not break')
    end

    setCuffed(src, false)
end)

-- qbx_medical takes the cuffs off a player who goes down
RegisterNetEvent('city_police:server:downUncuff', function()
    local src = source
    if isCuffed(src) and isDown(src) then setCuffed(src, false) end
end)

lib.callback.register('city_police:escort', function(source, target)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target)
    if not target then return false, 'too_far' end

    if escorts[target] then
        if escorts[target] ~= src then return false, 'escorted' end
        stopEscort(target)
        return true, false
    end

    if not isCuffed(target) and not isDown(target) then return false, 'not_restrained' end
    if IsPedInAnyVehicle(GetPlayerPed(target), false) then return false, 'in_vehicle' end

    for escorted, officer in pairs(escorts) do
        if officer == src then stopEscort(escorted) end
    end

    escorts[target] = src
    TriggerClientEvent('city_police:client:escorted', target, true, src)
    TriggerClientEvent('city_police:client:escorting', src, true)

    return true, true
end)

-- The escorted player stops being escorted on their side (went down, qbx_medical)
RegisterNetEvent('city_police:server:escortEnded', function()
    stopEscort(source)
end)

local MAX_SEAT = 14 -- passenger seats are 0 (front) and up; -1, the driver's, is never offered

lib.callback.register('city_police:putInVehicle', function(source, target, netId, seat)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target, Config.Ranges.player + 1.0)
    if not target then return false, 'too_far' end
    if not isCuffed(target) and not isDown(target) then return false, 'not_restrained' end

    seat = math.tointeger(seat)
    if seat ~= nil and (seat < 0 or seat > MAX_SEAT) then return false, 'invalid' end

    local vehicle = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end
    if not police.near(src, GetEntityCoords(vehicle), Config.Ranges.vehicle) then return false, 'too_far' end
    if seat and GetPedInVehicleSeat(vehicle, seat) ~= 0 then return false, 'seat_taken' end

    stopEscort(target)
    TriggerClientEvent('city_police:client:enterVehicle', target, netId, seat)

    return true
end)

lib.callback.register('city_police:takeOutOfVehicle', function(source, target)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target, Config.Ranges.vehicle)
    if not target then return false, 'too_far' end
    if not IsPedInAnyVehicle(GetPlayerPed(target), false) then return false end
    if not isCuffed(target) and not isDown(target) then return false, 'not_restrained' end

    TriggerClientEvent('city_police:client:leaveVehicle', target)

    return true
end)

-- Statuses other scripts give a player (alcohol, smells...). Kept here so an officer can check them.
RegisterNetEvent('city_police:server:status', function(id, seconds)
    local src = source
    seconds = math.tointeger(seconds)

    if not status.IDS[id] or not seconds or seconds < 0 then return end

    status.add(src, id, math.min(seconds, MAX_STATUS_SECONDS))
end)

lib.callback.register('city_police:checkStatus', function(source, target)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target)
    if not target then return false, 'too_far' end

    return true, status.active(target)
end)

lib.callback.register('city_police:anklet', function(source, target)
    local src = source
    if not police.can(src, 'anklet') then return false, 'feature_off' end

    target = police.reach(src, target)
    if not target then return false, 'too_far' end

    local data = metadata(target)
    local on = not data.tracker

    if on and not isCuffed(target) then return false, 'not_restrained' end

    exports.qbx_core:SetMetadata(target, 'tracker', on)
    police.notify(target, on and 'anklet_on_you' or 'anklet_off_you', 'inform')
    TriggerEvent('city_police:server:unitsChanged')

    return true, on
end)

AddEventHandler('playerDropped', function()
    local src = source

    stopEscort(src)
    for escorted, officer in pairs(escorts) do
        if officer == src then stopEscort(escorted) end
    end

    cuffs[src] = nil
end)

exports('IsCuffed', function(target)
    return type(target) == 'number' and isCuffed(target)
end)

---Cuffs or uncuffs a player from another resource (the Staff app). Returns the new state.
exports('SetCuffed', function(target, on)
    if type(target) ~= 'number' or not exports.qbx_core:GetPlayer(target) then return end
    if on == nil then on = not isCuffed(target) end

    setCuffed(target, on == true, false, 0)

    return on == true
end)
