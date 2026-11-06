-- Trading between two players. Each side's offer is its own small inventory, so offered items are held aside (they
-- can't be used or moved elsewhere) until the trade completes or is cancelled and they go back to their owner.

local Inventory = require 'server.inventory'
local players = require 'server.players'
local drops = require 'server.drops'

local trades = {}

---Set by server/main.lua (left nil in unit tests): recognises the cash item and moves offered cash back to a pocket
---in the ledger (the offer counts as ground)
---@type { isCash: fun(name: string): boolean, toPocket: fun(inventory: Inventory, amount: integer): boolean, toGround: fun(inventory: Inventory, amount: integer): boolean }?
trades.cashHooks = nil

local REQUEST_COOLDOWN_SECONDS = 5
local REQUEST_TIMEOUT_MS = 20000

---@class Trade
---@field a integer
---@field b integer
---@field offers table<integer, Inventory>
---@field accepted table<integer, boolean>

---@type table<integer, Trade>
local bySrc = {}

---@type table<integer, integer> os.time() of each player's last request
local lastRequest = {}

---@param trade Trade
---@param src integer
---@return integer
local function partnerOf(trade, src)
    return trade.a == src and trade.b or trade.a
end

---@param src integer
---@return string
local function nameOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local charinfo = player and player.PlayerData.charinfo

    return charinfo and ('%s %s'):format(charinfo.firstname, charinfo.lastname) or GetPlayerName(src) or tostring(src)
end

---@param src integer
---@return boolean
local function canTrade(src)
    local player = exports.qbx_core:GetPlayer(src)
    local metadata = player and player.PlayerData.metadata

    return players.get(src) ~= nil and metadata ~= nil
        and not metadata.isdead and not metadata.inlaststand and not metadata.ishandcuffed
end

---@param a integer
---@param b integer
---@return boolean
local function areClose(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b))) <= Config.TradeDistance
end

---What one side sees: their own offer and the partner's.
---@param trade Trade
---@param src integer
---@return table
local function viewFor(trade, src)
    local partner = partnerOf(trade, src)

    return {
        partner = nameOf(partner),
        slots = Config.TradeSlots,
        offer = trade.offers[src].items,
        their = trade.offers[partner].items,
        accepted = trade.accepted[src],
        theirAccepted = trade.accepted[partner],
    }
end

---@param trade Trade
---@param event string
local function sendBoth(trade, event)
    for _, src in ipairs({ trade.a, trade.b }) do
        TriggerClientEvent(event, src, viewFor(trade, src))
    end
end

---@param src integer
---@return Trade?
function trades.get(src)
    return bySrc[src]
end

---The player's own offer, for moving items in and out of it.
---@param src integer
---@return Inventory?
---@return string? reason
function trades.offer(src)
    local trade = bySrc[src]
    if not trade then return nil, 'trade_closed' end

    if not areClose(trade.a, trade.b) then
        trades.cancel(src, 'trade_too_far')
        return nil, 'trade_closed'
    end

    return trade.offers[src]
end

---Anything changed: both have to accept again.
---@param src integer
function trades.changed(src)
    local trade = bySrc[src]
    if not trade then return end

    trade.offers[trade.a]:takeChanges()
    trade.offers[trade.b]:takeChanges()
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false

    sendBoth(trade, 'city_inventory:client:updateTrade')
end

---Asks `target` whether they want to trade with `src`, and opens the trade for both when they say yes. Yields.
---@param src integer
---@param target unknown
---@return boolean success
---@return string? reason
function trades.request(src, target)
    target = math.tointeger(tonumber(target))
    if not target or target == src or not GetPlayerName(target) then return false, 'trade_no_player' end

    local now = os.time()
    if lastRequest[src] and now - lastRequest[src] < REQUEST_COOLDOWN_SECONDS then return false, 'busy' end
    lastRequest[src] = now

    if not canTrade(src) or not canTrade(target) then return false, 'trade_busy' end
    if bySrc[src] or bySrc[target] then return false, 'trade_busy' end
    if not areClose(src, target) then return false, 'too_far' end

    local answer = promise.new()
    local answered = false

    lib.callback('city_inventory:askTrade', target, function(accepted)
        if answered then return end
        answered = true
        answer:resolve(accepted == true)
    end, nameOf(src))

    SetTimeout(REQUEST_TIMEOUT_MS, function()
        if answered then return end
        answered = true
        answer:resolve(false)
    end)

    if not Citizen.Await(answer) then return false, 'trade_declined' end

    -- Things may have changed while the other player was deciding
    if not GetPlayerName(src) or not GetPlayerName(target) then return false, 'trade_no_player' end
    if not canTrade(src) or not canTrade(target) or bySrc[src] or bySrc[target] then return false, 'trade_busy' end
    if not areClose(src, target) then return false, 'too_far' end

    local trade = { a = src, b = target, offers = {}, accepted = {} }

    for _, side in ipairs({ src, target }) do
        local offer = Inventory.new(('trade:%s'):format(side), Config.TradeSlots, Config.TradeMaxWeight)
        offer.type = 'trade'
        offer.id = side

        trade.offers[side] = offer
        trade.accepted[side] = false
        bySrc[side] = trade
    end

    sendBoth(trade, 'city_inventory:client:openTrade')

    return true
end

---Gives an offer's items to `owner`, dropping on the ground whatever doesn't fit.
---@param offer Inventory
---@param owner integer
local function giveOffer(offer, owner)
    local inventory = players.get(owner)
    local leftovers = {}

    local hooks = trades.cashHooks

    for _, item in pairs(offer.items) do
        -- Cash leaves the offer (ground) for the pocket in the ledger first; if that fails it goes on the ground
        local isCash = hooks and hooks.isCash(item.name)
        local moved = inventory and (not isCash or hooks.toPocket(inventory, item.count))

        if not moved or not inventory:add(item.name, item.count, item.metadata) then
            if moved and isCash then hooks.toGround(inventory, item.count) end
            leftovers[#leftovers + 1] = { name = item.name, count = item.count, metadata = item.metadata }
        end
    end

    if #leftovers > 0 then
        lib.print.warn(('Trade: %d stacks did not fit in %s\'s inventory and were dropped on the ground'):format(#leftovers, owner))
        drops.custom(leftovers, GetEntityCoords(GetPlayerPed(owner)), nil, nil, true)
    end

    if inventory then players.sync(owner) end
end

---@param trade Trade
local function finish(trade)
    bySrc[trade.a], bySrc[trade.b] = nil, nil
end

---Cancels the trade the player is in; both get their offers back.
---@param src integer
---@param reason? string locale key (error_<reason>) shown to both
function trades.cancel(src, reason)
    local trade = bySrc[src]
    if not trade then return end

    finish(trade)

    for _, side in ipairs({ trade.a, trade.b }) do
        giveOffer(trade.offers[side], side)

        if GetPlayerName(side) then
            TriggerClientEvent('city_inventory:client:closeTrade', side, reason or 'trade_cancelled')
        end
    end
end

---Could `inventory` take everything in `offer`? Tried on a copy, so nothing changes.
---@param inventory Inventory
---@param offer Inventory
---@return boolean
local function fits(inventory, offer)
    local copy = Inventory.new('dry-run', inventory.slotCount, inventory.maxWeight, inventory:serialize())

    for _, item in pairs(offer.items) do
        if not copy:add(item.name, item.count, item.metadata) then return false end
    end

    return true
end

---@param trade Trade
local function complete(trade)
    local a, b = trade.a, trade.b

    for _, side in ipairs({ a, b }) do
        local partner = partnerOf(trade, side)
        local problem

        if not fits(players.get(side), trade.offers[partner]) then
            problem = 'trade_full'
        end

        if problem then
            trade.accepted[a], trade.accepted[b] = false, false
            sendBoth(trade, 'city_inventory:client:updateTrade')
            TriggerClientEvent('city_inventory:client:tradeProblem', a, problem, nameOf(side))
            TriggerClientEvent('city_inventory:client:tradeProblem', b, problem, nameOf(side))
            return
        end
    end

    finish(trade)

    giveOffer(trade.offers[a], b)
    giveOffer(trade.offers[b], a)

    TriggerClientEvent('city_inventory:client:closeTrade', a, 'trade_done')
    TriggerClientEvent('city_inventory:client:closeTrade', b, 'trade_done')
end

---Marks the player's side as accepted (or not); the trade happens once both have.
---@param src integer
---@param accepted unknown
---@return boolean success
---@return string? reason
function trades.accept(src, accepted)
    local trade = bySrc[src]
    if not trade then return false, 'trade_closed' end

    if not areClose(trade.a, trade.b) then
        trades.cancel(src, 'trade_too_far')
        return false, 'trade_closed'
    end

    trade.accepted[src] = accepted == true

    if trade.accepted[trade.a] and trade.accepted[trade.b] then
        complete(trade)
    else
        sendBoth(trade, 'city_inventory:client:updateTrade')
    end

    return true
end

---Cancels every trade (resource stopping), so offered items are back in inventories before they're saved.
function trades.cancelAll()
    for src in pairs(bySrc) do
        trades.cancel(src)
    end
end

-- Walking apart, going down or getting cuffed ends the trade
CreateThread(function()
    while true do
        Wait(1000)

        for src, trade in pairs(bySrc) do
            if src == trade.a and (not areClose(trade.a, trade.b) or not canTrade(trade.a) or not canTrade(trade.b)) then
                trades.cancel(src, 'trade_too_far')
            end
        end
    end
end)

-- Trades themselves are cancelled from server/main.lua before the player's inventory is unloaded
AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
end)

return trades
