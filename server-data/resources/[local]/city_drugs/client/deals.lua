-- Phone deals: the dealer gives an order, a route leads to the drop-off, the buyer waits there
local util = require 'client.util'

local PED_DISTANCE = 50.0

local dealerPoint
local dealer
---@type { drop: integer, blip: integer, point: CPoint, buyer?: integer }?
local active

---@param model integer
---@param coords vector4
---@param scenario string?
---@return integer
local function spawnPed(model, coords, scenario)
    lib.requestModel(model)

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end

    return ped
end

local function deletePed(ped)
    if not ped then return end

    exports.ox_target:removeLocalEntity(ped)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
end

local function endDeal()
    if not active then return end

    RemoveBlip(active.blip)
    active.point:remove()
    deletePed(active.buyer)
    active = nil
end

local function deliver()
    util.setBusy(true)

    local done = lib.progressCircle({
        duration = 2500,
        label = locale('dealing'),
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    })

    if not done then
        util.setBusy(false)
        return exports.qbx_core:Notify(locale('canceled'), 'error')
    end

    local ok, result = lib.callback.await('city_drugs:deal:deliver', false)
    util.setBusy(false)

    if not ok then return exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error') end

    exports.qbx_core:Notify(locale('deal_paid', result), 'success')
    endDeal()
end

local function startDeal(order)
    local drop = Config.DropOffs[order.drop]
    if not drop then return end

    local blip = AddBlipForCoord(drop.coords.x, drop.coords.y, drop.coords.z)
    SetBlipSprite(blip, 514)
    SetBlipColour(blip, 1)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('deal_blip'))
    EndTextCommandSetBlipName(blip)

    active = { drop = order.drop, blip = blip }

    active.point = lib.points.new({
        coords = drop.coords.xyz,
        distance = PED_DISTANCE,
        onEnter = function()
            if not active or active.buyer then return end

            active.buyer = spawnPed(Config.Buyer.model, drop.coords, 'WORLD_HUMAN_STAND_MOBILE')
            exports.ox_target:addLocalEntity(active.buyer, {
                {
                    name = 'city_drugs:buyer',
                    label = locale('target_buyer'),
                    icon = 'fas fa-handshake',
                    distance = Config.UseDistance,
                    canInteract = function() return not cache.vehicle and not util.busy() end,
                    onSelect = deliver,
                },
            })
        end,
        onExit = function()
            if not active then return end

            deletePed(active.buyer)
            active.buyer = nil
        end,
    })

    exports.qbx_core:Notify(locale('deal_taken', order.amount, order.label), 'inform')
end

local function ask()
    if active then return exports.qbx_core:Notify(locale('error_active'), 'error') end

    local ok, result = lib.callback.await('city_drugs:deal:ask', false)
    if not ok then return exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error') end

    startDeal(result)
end

dealerPoint = lib.points.new({
    coords = Config.Dealer.coords.xyz,
    distance = PED_DISTANCE,
    onEnter = function()
        if dealer then return end

        dealer = spawnPed(Config.Dealer.model, Config.Dealer.coords, 'WORLD_HUMAN_SMOKING')
        exports.ox_target:addLocalEntity(dealer, {
            {
                name = 'city_drugs:dealer',
                label = locale('target_dealer'),
                icon = 'fas fa-comment-dollar',
                distance = Config.UseDistance,
                canInteract = function() return not cache.vehicle and not util.busy() end,
                onSelect = ask,
            },
        })
    end,
    onExit = function()
        deletePed(dealer)
        dealer = nil
    end,
})

-- The server says the deal ran out
RegisterNetEvent('city_drugs:client:dealEnded', endDeal)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    endDeal()
    deletePed(dealer)
    dealerPoint:remove()
end)
