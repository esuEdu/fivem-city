-- Speed cameras. The driver's client says it passed one; the speed is read from the vehicle here. Speeding becomes a
-- bank bill and a record; a flagged plate becomes a call.

local dispatch = require 'server.dispatch'
local police = require 'server.police'
local plates = require 'server.plates'
local records = require 'server.records'
local settings = require 'server.config'

local RADAR_REACH = 45.0
local EXCESSIVE_OVER = 40
---@type table<integer, integer> driver -> os.time of the last ticket
local lastTicket = {}
---@type table<string, integer> plate -> os.time of the last flagged-plate call
local lastFlagCall = {}

---@param src integer
---@param citizenid string
---@param name string
---@param over number
---@param limit integer
local function ticket(src, citizenid, name, over, limit)
    local crime = records.crime(over >= EXCESSIVE_OVER and 'speeding_excessive' or 'speeding')
    if not crime then return end

    local label = locale('radar_bill', math.floor(limit + over), limit)
    if not exports.city_bank:CreateBill(src, crime.fine, label) then return end

    records.add({
        citizenid = citizenid, name = name, kind = 'fine',
        charges = { { id = crime.id, title = crime.title, count = 1 } },
        months = 0, fine = crime.fine, points = crime.points, notes = label,
        officer = locale('radar'), officerCid = 'radar',
    })

    police.notify(src, 'radar_ticket', 'error', crime.fine)
end

RegisterNetEvent('city_police:server:radar', function(index)
    local src = source
    local radar = math.type(index) == 'integer' and Config.Radars.locations[index]
    if not Config.Radars.enabled or not radar then return end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if not police.near(src, radar.coords, RADAR_REACH) then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local plate = GetVehicleNumberPlateText(vehicle):match('^%s*(.-)%s*$')
    local flag = plates.get(plate)
    local now = os.time()

    if flag and (not lastFlagCall[plate] or now - lastFlagCall[plate] > 120) then
        lastFlagCall[plate] = now

        dispatch.add({
            kind = 'radar',
            code = '10-38',
            title = locale('call_flagged_plate', plate),
            text = locale(('plate_%s'):format(flag.status)),
            coords = radar.coords,
            priority = 2,
        })
    end

    -- Police, EMS and other emergency vehicles aren't ticketed
    if GetVehicleType(vehicle) ~= 'automobile' and GetVehicleType(vehicle) ~= 'bike' then return end
    local job = player.PlayerData.job
    if job.onduty and (job.type == 'leo' or job.type == 'ems') then return end

    local velocity = GetEntityVelocity(vehicle)
    local speed = #velocity * (Config.Radars.kmh and 3.6 or 2.236936)
    local over = speed - radar.limit

    if over < Config.Radars.tolerance then return end
    if lastTicket[src] and now - lastTicket[src] < settings.radarCooldown then return end

    lastTicket[src] = now
    ticket(src, player.PlayerData.citizenid, police.fullName(player), over, radar.limit)
end)

AddEventHandler('playerDropped', function()
    lastTicket[source] = nil
end)
