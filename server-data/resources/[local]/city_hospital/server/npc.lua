-- "Desperate prayer": with no EMS on duty, a downed player can call an NPC ambulance once per fall. The client plays the
-- scene (ambulance driving over, paramedic doing CPR); the server only revives once the minimum time has passed.
local charges = require 'server.charges'
local settings = require 'server.config'
local state = require 'server.state'

---@type table<integer, { token: string, since: integer }>
local visits = {}

lib.callback.register('city_hospital:pray', function(source)
    local src = source
    local info = state.down(src)

    if not info then return false, 'not_down' end
    if state.isFinalized(src) then return false, 'finalized' end
    if info.prayed then return false, 'already_prayed' end
    if state.emsOnDuty() > 0 then return false, 'ems_on_duty' end

    info.prayed = true
    charges.take(src, settings.prices.prayer, 'hospital-prayer', 'Private ambulance')

    local token = lib.string.random('............')

    visits[src] = { token = token, since = os.time() }

    return true, token
end)

-- The paramedic finished: revive with a little health, if the scene really took long enough
lib.callback.register('city_hospital:prayerDone', function(source, token)
    local src = source
    local visit = visits[src]

    if not visit or visit.token ~= token then return false end

    local elapsed = os.time() - visit.since

    if elapsed > settings.times.npcTimeout then
        visits[src] = nil
        return false
    end

    if elapsed < settings.times.npcMinimum then
        exports.city_economy:Flag(src, 'hospital_npc_fast', 3, { elapsed = elapsed })
        return false
    end

    visits[src] = nil

    if not state.down(src) or state.isFinalized(src) then return false end

    exports.qbx_medical:Revive(src)
    exports.qbx_medical:HealPartially(src)

    return true
end)

state.onUp(function(src) visits[src] = nil end)

AddEventHandler('city_hospital:server:finalized', function(src)
    if visits[src] then
        visits[src] = nil
        TriggerClientEvent('city_hospital:client:prayerCancelled', src)
    end
end)
