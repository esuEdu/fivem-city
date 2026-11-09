local common = require 'server.common'
local bags = require 'server.bags'
local payout = require 'server.payout'
local settings = require 'server.config'

local atm = Config.Atm

-- Blown ATMs: { coords, untilTime }. The server can't see map props, so "the same ATM" is anything this close.
local blown = {}

---@param coords vector3
---@return boolean
local function onCooldown(coords)
    local now = os.time()

    for i = #blown, 1, -1 do
        local entry = blown[i]
        if entry.untilTime <= now then
            table.remove(blown, i)
        elseif #(entry.coords - coords) <= atm.sameDistance then
            return true
        end
    end

    return false
end

lib.callback.register('city_robbery:plantAtm', function(source, atmCoords)
    local src = source
    if not exports.qbx_core:GetPlayer(src) then return false end

    local coords = common.toVec(atmCoords)
    if not coords then
        common.warn(src, 'sent bad ATM coords')
        return common.deny(src, 'failed', 'bad ATM coords')
    end

    if common.session(src) then return common.deny(src, 'busy') end
    if not common.near(src, coords, atm.maxDistance) then return common.deny(src, 'too_far') end
    if common.isDown(src) then return common.deny(src, 'cant_now') end
    if onCooldown(coords) then return common.deny(src, 'atm_cooldown') end
    if exports.city_inventory:GetItemCount(src, atm.item) < 1 then return common.deny(src, 'no_c4') end

    common.start(src, { kind = 'atm', coords = coords, ttl = (atm.plantSeconds + 30) * 1000 })

    return true
end)

---When the fuse runs out: the explosion, the bag where the robber planted it and the police call.
---@param src integer
---@param coords vector3
---@param bagCoords vector3
local function detonate(src, coords, bagCoords)
    if GetPlayerName(src) then TriggerClientEvent('city_robbery:client:explode', src, coords) end

    local officers = common.policeOnDuty()
    local amount = payout.atm(settings.atm.base, settings.atm.perOfficer, officers)

    bags.add('atm', bagCoords, amount)

    exports.city_police:Alert({
        title = locale('alert_atm'),
        text = locale('alert_atm_text'),
        coords = coords,
        code = '10-90',
        priority = 2,
    })

    lib.print.info(('city_robbery: player %s blew an ATM (%d officers on duty, $%d)'):format(src, officers, amount))
end

lib.callback.register('city_robbery:armAtm', function(source)
    local src = source
    if not exports.qbx_core:GetPlayer(src) then return false end

    local session = common.session(src)
    if not session or session.kind ~= 'atm' then return common.deny(src, 'failed', 'no ATM robbery going') end

    common.stop(src)

    if not common.waited(session, atm.plantSeconds) then
        common.warn(src, 'armed the C4 too fast')
        return common.deny(src, 'failed', 'armed too fast')
    end

    if not common.near(src, session.coords, atm.maxDistance + 1.0) then return common.deny(src, 'too_far') end
    if common.isDown(src) then return common.deny(src, 'cant_now') end
    -- Someone else blew it while this one was planting
    if onCooldown(session.coords) then return common.deny(src, 'atm_cooldown') end
    if not exports.city_inventory:RemoveItem(src, atm.item, 1) then return common.deny(src, 'no_c4') end

    blown[#blown + 1] = { coords = session.coords, untilTime = os.time() + atm.fuseSeconds + atm.cooldownSeconds }

    local bagCoords = GetEntityCoords(GetPlayerPed(src))

    SetTimeout(atm.fuseSeconds * 1000, function()
        detonate(src, session.coords, bagCoords)
    end)

    return true, atm.fuseSeconds
end)
