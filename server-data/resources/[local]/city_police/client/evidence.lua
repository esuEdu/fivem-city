-- Ground evidence. Every player: shots are reported (throttled) so the server drops a casing. Officers on duty:
-- the server sends them what's on the ground; aiming a flashlight shows it nearby, and E picks it up into a bag.

local job = require 'client.job'

local IGNORED = {
    [`weapon_unarmed`] = true, [`weapon_stungun`] = true, [`weapon_petrolcan`] = true, [`weapon_fireextinguisher`] = true,
    [`weapon_flashlight`] = true, [`weapon_nightstick`] = true, [`weapon_snowball`] = true, [`weapon_ball`] = true,
}
local PICK_KEY = 38 -- E
local MARKERS = { casing = { 255, 210, 80 }, blood = { 220, 40, 40 }, fingerprint = { 90, 170, 255 } }

---@type table<integer, { id: integer, kind: string, coords: vector3, label: string }>
local ground = {}
local watching = false
local shooting = false

-- Shots: a loop only while a real gun is in hand
local function watchShots()
    if shooting then return end
    shooting = true

    CreateThread(function()
        local last = 0

        while cache.weapon and not IGNORED[cache.weapon] do
            if IsPedShooting(cache.ped) then
                local now = GetGameTimer()

                if now - last >= Config.Evidence.casingEvery then
                    last = now
                    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, math.random() - 0.5, math.random() - 0.5, -0.9)
                    TriggerServerEvent('city_police:server:shot', coords)
                end
            end

            Wait(0)
        end

        shooting = false
    end)
end

lib.onCache('weapon', function(weapon)
    if weapon and not IGNORED[weapon] then SetTimeout(0, watchShots) end
end)

---@return boolean
local function aimingFlashlight()
    return cache.weapon == `weapon_flashlight` and IsPlayerFreeAiming(cache.playerId)
end

local function collect(item)
    if not lib.progressCircle({ duration = 2500, label = locale('collecting'), position = 'bottom', disable = { move = true, car = true, combat = true },
        anim = { dict = 'pickup_object', clip = 'pickup_low' } }) then
        return
    end

    local ok, reason = lib.callback.await('city_police:collectEvidence', false, item.id, job.place(item.coords))
    if not ok then return job.fail(reason) end

    exports.qbx_core:Notify(locale('evidence_collected'), 'success')
end

-- Drawing evidence: only while an officer on duty aims a flashlight
local function watchGround()
    if watching then return end
    watching = true

    CreateThread(function()
        while job.onDuty() and cache.weapon == `weapon_flashlight` do
            if aimingFlashlight() and next(ground) then
                local coords = GetEntityCoords(cache.ped)

                for _, item in pairs(ground) do
                    local distance = #(coords - item.coords)

                    if distance < Config.Evidence.seeDistance then
                        local color = MARKERS[item.kind]
                        DrawMarker(28, item.coords.x, item.coords.y, item.coords.z + 0.05, 0, 0, 0, 0, 0, 0, 0.08, 0.08, 0.08, color[1], color[2], color[3], 200, false, false, 2, false, nil, nil, false)

                        if distance < Config.Evidence.pickDistance then
                            qbx.drawText3d({ text = locale('evidence_pick', item.label), coords = item.coords + vec3(0.0, 0.0, 0.3) })
                            if IsControlJustReleased(0, PICK_KEY) then collect(item) end
                        end
                    end
                end

                Wait(0)
            else
                Wait(250)
            end
        end

        watching = false
    end)
end

lib.onCache('weapon', function(weapon)
    if weapon == `weapon_flashlight` and job.onDuty() then SetTimeout(0, watchGround) end
end)

RegisterNetEvent('city_police:client:evidenceAdded', function(item)
    if GetInvokingResource() or type(item) ~= 'table' then return end

    ground[item.id] = { id = item.id, kind = item.kind, coords = vec3(item.coords.x, item.coords.y, item.coords.z), label = item.label }
end)

RegisterNetEvent('city_police:client:evidenceRemoved', function(id)
    if GetInvokingResource() then return end

    ground[id] = nil
end)

AddEventHandler('city_police:client:dutyChanged', function(onDuty)
    ground = {}
    if not onDuty then return end

    for _, item in ipairs(lib.callback.await('city_police:evidenceList', false) or {}) do
        ground[item.id] = { id = item.id, kind = item.kind, coords = vec3(item.coords.x, item.coords.y, item.coords.z), label = item.label }
    end
end)

-- Other scripts give the player statuses an officer can see (qbx_consumables: alcohol, pupils, weed smell)
AddEventHandler('evidence:client:SetStatus', function(id, seconds)
    if type(id) ~= 'string' or type(seconds) ~= 'number' then return end

    TriggerServerEvent('city_police:server:status', id, math.floor(seconds))
end)
