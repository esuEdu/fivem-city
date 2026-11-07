-- The downed screen's data, the hospital respawn, /finalizado and checking a pulse
lib.locale()

local beds = require 'server.beds'
local charges = require 'server.charges'
local settings = require 'server.config'
local sos = require 'server.sos'
local state = require 'server.state'

local THROTTLE_MS = 500
local last = {}

---@param src integer
---@param key string
---@return boolean
local function throttled(src, key)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey

    if byKey[key] and now - byKey[key] < THROTTLE_MS then return true end

    byKey[key] = now
    return false
end

---@param src integer
---@param target integer
---@param range number
---@return boolean
local function near(src, target, range)
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) <= range
end

-- What the downed screen shows. Polled every couple of seconds while down.
lib.callback.register('city_hospital:status', function(source)
    local src = source

    if throttled(src, 'status') then return end

    local info = state.down(src)
    if not info then return { down = false } end

    local ems = state.emsOnDuty()
    local call = sos.of(src)
    local finalized = state.isFinalized(src)

    return {
        down = true,
        finalized = finalized,
        remaining = state.remaining(src, settings.times.downWait),
        ems = ems,
        sos = call and { accepted = call.acceptedBy } or nil,
        canPray = ems == 0 and not finalized and not info.prayed,
        prices = { respawn = settings.prices.respawn, prayer = settings.prices.prayer },
    }
end)

-- Respawning at the hospital: only once the wait is over. Everything carried is lost.
lib.callback.register('city_hospital:respawn', function(source)
    local src = source

    if throttled(src, 'respawn') then return false end
    if not state.down(src) or state.remaining(src, settings.times.downWait) > 0 then return false end

    local hospital = beds.nearestHospital(src)
    local bed = beds.free(hospital)

    -- Clear first (cash in the pockets is written off in the ledger), then bring the player back
    exports.city_inventory:ClearInventory(src)
    exports.qbx_medical:Revive(src)

    charges.take(src, settings.prices.respawn, 'hospital-respawn', 'Hospital respawn')

    -- A free bed if there is one; otherwise the player wakes up at the reception
    beds.release(src)

    if bed and beds.claim(src, hospital, bed, true, settings.times.bedTreatment) then
        TriggerClientEvent('city_hospital:client:toBed', src, hospital, bed, settings.times.bedTreatment)
    else
        TriggerClientEvent('city_hospital:client:toReception', src, hospital)
        exports.qbx_medical:Heal(src)
    end
    lib.print.info(('city_hospital: %s respawned at %s'):format(GetPlayerName(src), hospital))

    return true
end)

-- /finalizado: finish off the downed player right next to you. With more than one body in reach, it refuses.
lib.addCommand('finalizado', {
    help = locale('command_finalize'),
}, function(source)
    local src = source

    if src == 0 or throttled(src, 'finalize') then return end
    if state.down(src) then return end

    local found = {}

    for _, target in ipairs(GetPlayers()) do
        target = tonumber(target)

        if target ~= src and state.down(target) and near(src, target, settings.ranges.finalize) then
            found[#found + 1] = target
        end
    end

    if #found == 0 then return exports.qbx_core:Notify(src, locale('error_no_body'), 'error') end
    if #found > 1 then return exports.qbx_core:Notify(src, locale('error_many_bodies'), 'error') end

    local target = found[1]

    if state.isFinalized(target) then return exports.qbx_core:Notify(src, locale('error_already_finalized'), 'error') end

    local actor = exports.qbx_core:GetPlayer(src)

    state.finalize(target, actor.PlayerData.citizenid)
    TriggerEvent('city_hospital:server:finalized', target)

    exports.qbx_core:Notify(src, locale('notify_finalized_done'), 'inform')
    exports.qbx_core:Notify(target, locale('notify_finalized'), 'error')
    lib.print.info(('city_hospital: %s (%s) finished off %s'):format(GetPlayerName(src), actor.PlayerData.citizenid, GetPlayerName(target)))
end)

-- Checking a pulse: unconscious, or gone (finished off). Anyone next to the body can.
lib.callback.register('city_hospital:pulse', function(source, target)
    local src = source

    if throttled(src, 'pulse') or type(target) ~= 'number' or not GetPlayerName(target) then return end
    if not near(src, target, settings.ranges.interact) then return end
    if not state.down(target) then return 'alive' end

    return state.isFinalized(target) and 'gone' or 'unconscious'
end)

-- Getting out of a bed (after a respawn, the reception or lying down to be treated)
lib.callback.register('city_hospital:bedDone', function(source)
    local src = source

    if throttled(src, 'bedDone') then return false end

    return beds.finish(src)
end)

lib.callback.register('city_hospital:leaveBed', function(source)
    beds.release(source)
    return true
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

-- For other medic scripts: a finished-off player must not be revived (staff revives still work)
exports('IsFinalized', state.isFinalized)
exports('IsDown', function(src) return state.down(src) ~= nil end)
