-- Radio codes from the patrol car menu (F6): a popup for every unit on duty, or a dispatch call for the urgent ones
-- (Config.RadioCodes call = true), and the sender's status when the code says so.

local police = require 'server.police'
local roster = require 'server.roster'
local dispatch = require 'server.dispatch'

local last = {}

RegisterNetEvent('city_police:server:radioCode', function(index)
    local src = source
    if not exports.qbx_core:GetPlayer(src) or not police.onDuty(src) then return end

    local entry = Config.RadioCodes[math.tointeger(index) or 0]
    if not entry then return police.warn(src, 'sent an unknown radio code') end

    local now = os.time()
    if last[src] and now - last[src] < Config.RadioCooldown then return end
    last[src] = now

    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) == 0 then return end

    local unit = roster.unit(src)
    local from = unit and unit.callsign and ('%s · %s'):format(unit.callsign, police.name(src)) or police.name(src)
    local coords = GetEntityCoords(ped)

    if entry.status then roster.setStatus(src, entry.status) end

    if entry.call then
        dispatch.add({ kind = 'alert', code = entry.code, title = entry.label, text = from, coords = coords, priority = entry.priority })
        return
    end

    police.toOnDuty('city_police:client:radioCode', { code = entry.code, label = entry.label, from = from, coords = coords })
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
