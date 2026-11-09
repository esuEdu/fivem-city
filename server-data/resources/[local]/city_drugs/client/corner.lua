-- Corner selling: an option on locals while carrying something to sell. The server rolls the offer.
local util = require 'client.util'

local CARRY_CHECK_MS = 1000
local FACE_MS = 1500

local lastCheck, carrying = 0, false

---Whether the player carries anything sellable, checked at most once a second (canInteract runs every frame)
local function hasDrugs()
    local now = GetGameTimer()
    if now - lastCheck < CARRY_CHECK_MS then return carrying end

    lastCheck = now
    carrying = false

    for _, count in pairs(exports.city_inventory:Search('count', Config.CornerItems) or {}) do
        if count > 0 then
            carrying = true
            break
        end
    end

    return carrying
end

local function canSellTo(entity)
    return not cache.vehicle and not util.busy() and not IsPedAPlayer(entity) and not IsPedDeadOrDying(entity, true)
        and not IsPedInAnyVehicle(entity, false) and GetPedType(entity) ~= 28 and NetworkGetEntityIsNetworked(entity)
        and hasDrugs()
end

local function sell(ped)
    util.setBusy(true)

    local ok, result = lib.callback.await('city_drugs:corner:ask', false, NetworkGetNetworkIdFromEntity(ped))

    if not ok then
        util.setBusy(false)
        return exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
    end

    if result.refused then
        util.setBusy(false)
        return exports.qbx_core:Notify(locale('corner_refused'), 'error')
    end

    TaskTurnPedToFaceEntity(ped, cache.ped, FACE_MS)

    local answer = lib.alertDialog({
        header = locale('corner_header'),
        content = locale('corner_offer', result.amount, result.label, result.total),
        centered = true,
        cancel = true,
    })

    if answer ~= 'confirm' then
        util.setBusy(false)
        return TriggerServerEvent('city_drugs:server:declineOffer')
    end

    local done = lib.progressCircle({
        duration = 2500,
        label = locale('dealing'),
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    })

    if not done then
        util.setBusy(false)
        TriggerServerEvent('city_drugs:server:declineOffer')
        return exports.qbx_core:Notify(locale('canceled'), 'error')
    end

    local sold, total = lib.callback.await('city_drugs:corner:sell', false)
    util.setBusy(false)

    if not sold then return exports.qbx_core:Notify(locale(('error_%s'):format(total or 'failed')), 'error') end

    lastCheck = 0
    exports.qbx_core:Notify(locale('sold', total), 'success')
end

exports.ox_target:addGlobalPed({
    {
        name = 'city_drugs:corner',
        label = locale('target_sell'),
        icon = 'fas fa-cannabis',
        distance = Config.UseDistance,
        canInteract = canSellTo,
        onSelect = function(data) sell(data.entity) end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalPed('city_drugs:corner')
end)
