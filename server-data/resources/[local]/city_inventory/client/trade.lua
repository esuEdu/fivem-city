-- Trading with another player: the "Trade" option on players, the accept popup, and the trade panel. The server keeps
-- the offers and decides everything; this only shows them and passes on clicks.

local other = require 'client.other'

local REQUEST_TIMEOUT_MS = 15000
local TARGET_DISTANCE = 2.5

local trade = {}

---@class TradeHooks
---@field open fun(): boolean
---@field notifyFailure fun(reason?: string)

---@type TradeHooks
local hooks

---@param hookFns TradeHooks
function trade.init(hookFns)
    hooks = hookFns
end

---@param view table what the server sends: partner, slots, offer, their, cash, theirCash, accepted, theirAccepted
local function send(view)
    SendNUIMessage({
        action = 'setTrade',
        partner = view.partner,
        slots = view.slots,
        offer = other.toEntries(view.offer),
        their = other.toEntries(view.their),
        cash = view.cash,
        theirCash = view.theirCash,
        accepted = view.accepted,
        theirAccepted = view.theirAccepted,
    })
end

---@param entity integer the player ped the target option was used on
local function requestTrade(entity)
    local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))

    lib.notify({ description = locale('trade_sent') })

    local success, reason = lib.callback.await('city_inventory:requestTrade', false, target)
    if not success then hooks.notifyFailure(reason) end
end

-- The other player asked to trade; answer yes or no (no answer in time is a no)
lib.callback.register('city_inventory:askTrade', function(name)
    local answered = false

    SetTimeout(REQUEST_TIMEOUT_MS, function()
        if not answered then lib.closeAlertDialog() end
    end)

    local answer = lib.alertDialog({
        header = locale('trade_request_title'),
        content = locale('trade_request', name),
        centered = true,
        cancel = true,
        labels = { confirm = locale('ui_accept'), cancel = locale('ui_decline') },
    })

    answered = true

    return answer == 'confirm'
end)

RegisterNetEvent('city_inventory:client:openTrade', function(view)
    other.setCurrent('trade')
    send(view)

    if not hooks.open() then
        TriggerServerEvent('city_inventory:server:closeOther')
    end
end)

RegisterNetEvent('city_inventory:client:updateTrade', send)

RegisterNetEvent('city_inventory:client:closeTrade', function(reason)
    other.setCurrent(nil)
    SendNUIMessage({ action = 'clearTrade' })

    if reason == 'trade_done' then
        lib.notify({ description = locale('trade_done'), type = 'success' })
    else
        hooks.notifyFailure(reason)
    end
end)

-- Both accepted but one side can't take the items or doesn't have the cash
RegisterNetEvent('city_inventory:client:tradeProblem', function(problem, name)
    lib.notify({ description = locale(problem, name), type = 'error' })
end)

RegisterNUICallback('tradeCash', function(data, cb)
    cb(1)

    local amount = tonumber(data.amount)
    if not amount then return end

    local success, reason = lib.callback.await('city_inventory:tradeCash', false, math.floor(amount))
    if not success then hooks.notifyFailure(reason) end
end)

RegisterNUICallback('tradeAccept', function(data, cb)
    cb(1)

    local success, reason = lib.callback.await('city_inventory:tradeAccept', false, data.accepted == true)
    if not success then hooks.notifyFailure(reason) end
end)

RegisterNUICallback('tradeCancel', function(_, cb)
    cb(1)
    TriggerServerEvent('city_inventory:server:closeOther')
end)

-- city_inventory starts before ox_target (server.cfg order), so wait for its exports
CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'city_inventory:trade',
            label = locale('target_trade'),
            icon = 'fas fa-handshake',
            distance = TARGET_DISTANCE,
            onSelect = function(data)
                CreateThread(function() requestTrade(data.entity) end)
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:removeGlobalPlayer('city_inventory:trade')
end)

return trade
