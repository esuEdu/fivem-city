-- Placing and removing police props (radial menu), and spike strips bursting the tyres of the car this player drives.

local job = require 'client.job'

local WHEELS = { { bone = 'wheel_lf', index = 0 }, { bone = 'wheel_rf', index = 1 }, { bone = 'wheel_lr', index = 4 }, { bone = 'wheel_rr', index = 5 } }
local SPIKE_HALF_LENGTH = 2.2
local SPIKE_WATCH = 40.0

---@param kind string a Config.Objects key, or 'spike'
local function place(kind)
    if not job.onDuty() or cache.vehicle then return end
    if kind ~= 'spike' and not Config.Objects[kind] then return end

    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, kind == 'spike' and 2.5 or 1.2, 0.0)
    local found, ground = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)

    if not lib.progressCircle({ duration = 1500, label = locale('placing'), position = 'bottom', disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@narcotics@trash', clip = 'drop_front' } }) then
        return
    end

    local ok, reason = lib.callback.await('city_police:placeObject', false, kind, vec3(coords.x, coords.y, found and ground or coords.z - 1.0), GetEntityHeading(cache.ped))
    if not ok then job.fail(reason) end
end

local function removeClosest()
    if not job.onDuty() then return end

    local coords = GetEntityCoords(cache.ped)
    local best, bestDistance = nil, 5.0

    for _, entity in ipairs(GetGamePool('CObject')) do
        if Entity(entity).state.policeObject then
            local distance = #(coords - GetEntityCoords(entity))
            if distance < bestDistance then best, bestDistance = entity, distance end
        end
    end

    if not best then return exports.qbx_core:Notify(locale('error_no_object'), 'error') end

    local ok = lib.callback.await('city_police:removeObject', false, NetworkGetNetworkIdFromEntity(best))
    if not ok then job.fail() end
end

AddEventHandler('city_police:client:placeObject', place)
AddEventHandler('city_police:client:removeObject', removeClosest)

-- Spike strips: while driving near one, check each wheel against the strip's line every frame
local spikeThread = false

---@param spike { x: number, y: number, z: number, h: number }
---@param point vector3
---@return boolean
local function onStrip(spike, point)
    local heading = math.rad(spike.h)
    local dx, dy = -math.sin(heading), math.cos(heading)
    local rx, ry = point.x - spike.x, point.y - spike.y
    local along = rx * dx + ry * dy
    local across = math.abs(rx * dy - ry * dx)

    return math.abs(along) <= 0.6 and across <= SPIKE_HALF_LENGTH and math.abs(point.z - spike.z) < 1.5
end

local function watchSpikes()
    if spikeThread then return end
    spikeThread = true

    CreateThread(function()
        while cache.vehicle and cache.seat == -1 do
            local spikes = GlobalState.policeSpikes or {}
            local coords = GetEntityCoords(cache.vehicle)
            local near = {}

            for _, spike in ipairs(spikes) do
                if #(coords - vec3(spike.x, spike.y, spike.z)) < SPIKE_WATCH then near[#near + 1] = spike end
            end

            if #near == 0 then
                Wait(1000)
            else
                for _, wheel in ipairs(WHEELS) do
                    local bone = GetEntityBoneIndexByName(cache.vehicle, wheel.bone)

                    if bone ~= -1 and not IsVehicleTyreBurst(cache.vehicle, wheel.index, false) then
                        local point = GetWorldPositionOfEntityBone(cache.vehicle, bone)

                        for _, spike in ipairs(near) do
                            if onStrip(spike, point) then SetVehicleTyreBurst(cache.vehicle, wheel.index, true, 1000.0) end
                        end
                    end
                end

                Wait(0)
            end
        end

        spikeThread = false
    end)
end

lib.onCache('seat', function(seat)
    if seat == -1 then SetTimeout(0, watchSpikes) end
end)
