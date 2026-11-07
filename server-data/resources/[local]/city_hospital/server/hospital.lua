-- Beds anyone can lie in to be treated (paid), and the NPC reception for when no EMS is on duty
local beds = require 'server.beds'
local charges = require 'server.charges'
local settings = require 'server.config'
local state = require 'server.state'

local doctorAlerted = 0

---@param src integer
---@param coords vector3
---@return boolean
local function at(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= settings.ranges.place
end

-- Lying down in a bed by yourself: treated after the bed time, pay when healed
lib.callback.register('city_hospital:lieDown', function(source, hospital, bed)
    local src = source
    local place = type(hospital) == 'string' and Config.Hospitals[hospital]
    local spot = place and type(bed) == 'number' and place.beds[bed]

    if not spot or state.down(src) then return false end
    if not at(src, spot.coords.xyz) then return false end

    if not beds.claim(src, hospital, bed, false, settings.times.bedTreatment) then return false end

    return true, settings.times.bedTreatment
end)

-- The reception: with no EMS on duty, pay and get a free bed; with EMS on duty, they get called instead
lib.callback.register('city_hospital:checkIn', function(source, hospital)
    local src = source
    local place = type(hospital) == 'string' and Config.Hospitals[hospital]

    if not place or not at(src, place.reception.xyz) or state.down(src) then return false end

    local count, ems = state.emsOnDuty()

    if count > 0 then
        if GetGameTimer() - doctorAlerted > 60000 then
            doctorAlerted = GetGameTimer()
            for i = 1, #ems do exports.qbx_core:Notify(ems[i], locale('notify_patient_waiting', place.label), 'inform') end
        end

        return false, 'ems_called'
    end

    local bed = beds.free(hospital)

    if not bed then return false, 'no_bed' end

    charges.take(src, settings.prices.reception, 'hospital-reception', 'Hospital reception')

    if not beds.claim(src, hospital, bed, true, settings.times.receptionTreatment) then return false, 'no_bed' end

    return true, bed, settings.times.receptionTreatment
end)
