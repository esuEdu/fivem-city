local common = require 'server.common'
local bags = require 'server.bags'
local settings = require 'server.config'

local store = Config.Store
local locations = require('@city_inventory.data.shops').General.locations

-- Store index -> os.time() when it may be robbed again
local cooldowns = {}

---@param src integer
---@param id integer
local function logOverride(src, id)
    lib.print.info(('city_robbery: staff %s started 24/7 #%d without enough police'):format(src, id))

    if GetResourceState('city_staff') == 'started' then
        exports.city_staff:Log(src, 'robbery_override', nil, ('24/7 #%d with fewer than %d police on duty'):format(id, store.minPolice))
    end
end

lib.callback.register('city_robbery:startStore', function(source, id)
    local src = source
    if not exports.qbx_core:GetPlayer(src) then return false end

    local location = math.type(id) == 'integer' and locations[id]
    if not location then
        common.warn(src, ('sent an unknown store %s'):format(id))
        return false
    end

    local coords = vec3(location.x, location.y, location.z)

    if common.session(src) then return false, 'busy' end
    if not common.near(src, coords, store.targetRadius + 2.0) then return false, 'too_far' end
    if common.isDown(src) then return false, 'cant_now' end
    if (cooldowns[id] or 0) > os.time() then return false, 'store_cooldown' end

    local override = false
    if common.policeOnDuty() < store.minPolice then
        if not common.isStaff(src) then return false, 'no_police' end

        override = true
        logOverride(src, id)
    end

    cooldowns[id] = os.time() + store.cooldownSeconds
    common.start(src, { kind = 'store', id = id, coords = coords, ttl = (store.seconds + 30) * 1000 })

    exports.city_police:Alert({
        title = locale('alert_store'),
        text = locale('alert_store_text'),
        coords = coords,
        code = '10-90',
        priority = 2,
    })

    return true, override
end)

lib.callback.register('city_robbery:finishStore', function(source)
    local src = source
    if not exports.qbx_core:GetPlayer(src) then return false end

    local session = common.session(src)
    if not session or session.kind ~= 'store' then return false end

    common.stop(src)

    if not common.waited(session, store.seconds) then
        common.warn(src, 'finished a store robbery too fast')
        return false
    end

    if not common.near(src, session.coords, store.maxDistance) then return false, 'too_far' end
    if common.isDown(src) then return false, 'cant_now' end

    bags.add('store', GetEntityCoords(GetPlayerPed(src)), settings.store.amount)

    lib.print.info(('city_robbery: player %s robbed 24/7 #%d ($%d)'):format(src, session.id, settings.store.amount))

    return true
end)
