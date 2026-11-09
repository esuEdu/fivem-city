-- Phone deals: the dealer hands out an order and a drop-off, the phone gets the details, the buyer pays on delivery.
-- One deal per player at a time, a cooldown per character, and the deal expires.
local settings = require 'server.config'
local common = require 'server.common'
local rules = require 'server.rules'

local deal = settings.deal
local EXPIRY_CHECK_MS = 30000

---@type table<integer, { item: string, amount: integer, payout: integer, drop: integer, expiresAt: integer }>
local deals = {}
---@type table<string, integer> citizenid -> os.time() of the last deal handed out
local lastDeal = {}

local function itemLabel(name)
    local item = exports.city_inventory:Items(name)

    return item and item.label or name
end

local function text(src, message)
    if GetResourceState('city_phone') == 'started' and exports.city_phone:HasPhone(src) then
        exports.city_phone:Notify(src, { app = 'messages', title = Config.DealContact, text = message })
    else
        exports.qbx_core:Notify(src, message, 'inform')
    end
end

lib.callback.register('city_drugs:deal:ask', function(source)
    local src = source
    local player, reason = common.player(src, 'deals')
    if not player then return false, reason end

    if not common.near(src, Config.Dealer.coords, Config.UseDistance + 2.0) then return false end
    if deals[src] then return false, 'active' end

    local now = os.time()
    local citizenid = player.PlayerData.citizenid
    if lastDeal[citizenid] and now - lastDeal[citizenid] < deal.cooldownMinutes * 60 then return false, 'wait' end
    if not common.enoughPolice('deal') then return false, 'quiet' end

    local order = rules.order(deal.orders, math.random)
    if not order then return false end

    order.drop = math.random(1, #Config.DropOffs)
    order.expiresAt = now + deal.minutes * 60
    deals[src] = order
    lastDeal[citizenid] = now

    local label = itemLabel(order.item)
    text(src, locale('deal_text', order.amount, label, Config.DropOffs[order.drop].label, deal.minutes))

    return true, { drop = order.drop, label = label, amount = order.amount }
end)

lib.callback.register('city_drugs:deal:deliver', function(source)
    local src = source
    local order = deals[src]
    if not order or os.time() > order.expiresAt then return false end
    if not common.player(src) then return false end

    local drop = Config.DropOffs[order.drop].coords
    if not common.near(src, drop, deal.dropRadius) then return false end

    local ok, err = common.exchange(src, { [order.item] = order.amount }, { [settings.payItem] = order.payout })
    if not ok then return false, err or 'missing' end

    deals[src] = nil

    common.record(src, 'sale', order.drug, order.payout)
    -- a bulk order is a lot of money in one place: the biggest risk of all
    common.alert(order.drug, 'sale', locale('alert_deal'), drop, order.payout)

    return true, order.payout
end)

AddEventHandler('playerDropped', function()
    deals[source] = nil
end)

CreateThread(function()
    while true do
        Wait(EXPIRY_CHECK_MS)

        local now = os.time()

        for src, order in pairs(deals) do
            if now > order.expiresAt then
                deals[src] = nil
                TriggerClientEvent('city_drugs:client:dealEnded', src)
                text(src, locale('deal_expired'))
            end
        end
    end
end)
