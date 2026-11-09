-- Ground evidence: casings from shooting, blood from wounds, fingerprints from robberies. Kept in memory for
-- Config.Evidence.minutes and sent only to officers on duty. Picking one up saves what it really is in
-- city_police_evidence; the bag only carries the row id, so the truth is learned by analyzing it (MDT Evidence tab).

local police = require 'server.police'
local status = require 'server.status'
local alerts = require 'server.alerts'

---@class GroundEvidence
---@field id integer
---@field kind 'casing' | 'blood' | 'fingerprint'
---@field coords vector3
---@field at integer
---@field data table what it really is (serial, citizenid, fingerprint)

---@type table<integer, GroundEvidence>
local ground = {}
local nextId = 0
---@type table<integer, integer> shooter -> GetGameTimer of their last casing
local lastCasing = {}
---@type table<integer, integer>
local lastDrop = {}

local LIFETIME = Config.Evidence.minutes * 60
local DROP_REACH = 8.0
local FINGERPRINT_CHANCE = 0.7

---What officers see on the ground (no hidden data).
---@param item GroundEvidence
local function public(item)
    return { id = item.id, kind = item.kind, coords = item.coords, label = item.data.label }
end

---@param kind string
---@param coords vector3
---@param data table
local function drop(kind, coords, data)
    nextId = nextId + 1

    local item = { id = nextId, kind = kind, coords = coords, at = os.time(), data = data }
    ground[item.id] = item

    police.toOnDuty('city_police:client:evidenceAdded', public(item))
end

---@param src integer
---@param coords unknown
---@return vector3?
local function nearCoords(src, coords)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    local point = vec3(x, y, z)
    if not police.near(src, point, DROP_REACH) then return end

    return point
end

---@param src integer
---@param ms integer
---@return boolean
local function tooSoon(src, ms)
    local now = GetGameTimer()
    if lastDrop[src] and now - lastDrop[src] < ms then return true end

    lastDrop[src] = now
    return false
end

-- The shooter's client reports each shot (throttled there); the weapon and serial are read here
RegisterNetEvent('city_police:server:shot', function(coords)
    local src = source
    local now = GetGameTimer()

    if lastCasing[src] and now - lastCasing[src] < Config.Evidence.casingEvery then return end

    local point = nearCoords(src, coords)
    if not point then return end

    local weapon = exports.city_inventory:GetCurrentWeapon(src)
    if not weapon or not weapon.metadata then return end

    lastCasing[src] = now
    status.add(src, 'gunpowder', 300)

    local item = exports.city_inventory:Items(weapon.name)

    drop('casing', point, {
        label = item and item.label or weapon.name,
        weapon = weapon.name,
        serial = weapon.metadata.serial,
    })

    alerts.shot(src, point, weapon)
end)

-- qbx_medical: a wounded player bleeds
RegisterNetEvent('evidence:server:CreateBloodDrop', function(_, _, coords)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or tooSoon(src, 5000) then return end

    local point = nearCoords(src, coords)
    if not point then return end

    drop('blood', point, { label = locale('evidence_blood'), citizenid = player.PlayerData.citizenid, bloodtype = player.PlayerData.metadata.bloodtype })
end)

-- Robbery scripts: whoever touched the safe, the glass, the panel
RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or tooSoon(src, 3000) or math.random() > FINGERPRINT_CHANCE then return end

    local point = nearCoords(src, coords) or GetEntityCoords(GetPlayerPed(src))

    drop('fingerprint', point, { label = locale('evidence_fingerprint'), fingerprint = player.PlayerData.metadata.fingerprint, citizenid = player.PlayerData.citizenid })
end)

-- An officer coming on duty gets what's on the ground now
lib.callback.register('city_police:evidenceList', function(source)
    if not police.onDuty(source) then return {} end

    local list, now = {}, os.time()

    for id, item in pairs(ground) do
        if now - item.at > LIFETIME then
            ground[id] = nil
        else
            list[#list + 1] = public(item)
        end
    end

    return list
end)

lib.callback.register('city_police:collectEvidence', function(source, id, place)
    local src = source
    if not police.onDuty(src) then return false end

    local item = math.type(id) == 'integer' and ground[id]
    if not item then return false, 'gone' end
    if not police.near(src, item.coords, Config.Evidence.pickDistance + 1.5) then return false, 'too_far' end
    if exports.city_inventory:GetItemCount(src, 'empty_evidence_bag') < 1 then return false, 'no_bag' end

    local officer = police.name(src)
    place = police.clean(place, 100)

    local rowId = MySQL.insert.await('INSERT INTO city_police_evidence (kind, place, result, collected_by, collected_at) VALUES (?, ?, ?, ?, ?)', {
        item.kind, place, json.encode(item.data), officer, os.time(),
    })
    if not rowId then return false end

    if not exports.city_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then return false, 'no_bag' end

    local metadata = {
        evidenceId = rowId,
        kind = item.kind,
        label = ('%s #%d'):format(item.data.label, rowId),
        description = locale('evidence_bag_description', item.data.label, place, officer),
    }

    if not exports.city_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
        exports.city_inventory:AddItem(src, 'empty_evidence_bag', 1)
        return false, 'inventory_full'
    end

    ground[id] = nil
    police.toOnDuty('city_police:client:evidenceRemoved', id)

    return true
end)

AddEventHandler('playerDropped', function()
    lastCasing[source] = nil
    lastDrop[source] = nil
end)

CreateThread(function()
    while true do
        Wait(60000)

        local now = os.time()
        for id, item in pairs(ground) do
            if now - item.at > LIFETIME then
                ground[id] = nil
                police.toOnDuty('city_police:client:evidenceRemoved', id)
            end
        end
    end
end)
