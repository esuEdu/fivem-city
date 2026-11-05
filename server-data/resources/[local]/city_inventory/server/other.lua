-- The second panel next to the player's inventory: a stash, a shop, the ground, a trade or a searched player. A player has at most one
-- open; opening one closes the others. The client names a side and a slot; the server works out which inventory that is.

local Inventory = require 'server.inventory'
local actor = require 'server.actor'
local players = require 'server.players'
local stashes = require 'server.stashes'
local shops = require 'server.shops'
local drops = require 'server.drops'
local trades = require 'server.trades'
local vehicles = require 'server.vehicles'
local searches = require 'server.searches'

local getActor, toInteger = actor.getActor, actor.toInteger

local other = {}

---@param src integer
function other.closeAll(src)
    stashes.close(src)
    shops.close(src)
    drops.close(src)
    trades.cancel(src)
    searches.close(src)
end

-- Opening a stash from the client (ox_inventory's openInventory('stash', id)); the server checks job, distance and hooks
lib.callback.register('city_inventory:openStash', function(source, id)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end
    if type(id) ~= 'string' then return false, 'no_stash' end

    other.closeAll(src)
    return stashes.open(src, id)
end)

-- ox_inventory's openInventory('shop', { type, id }); the server checks job, licence, distance and price
lib.callback.register('city_inventory:openShop', function(source, shopType, id)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    other.closeAll(src)
    return shops.open(src, shopType, id)
end)

-- Opening the inventory at the back of a car (trunk) or sitting in one (glovebox)
lib.callback.register('city_inventory:openVehicle', function(source, netId, kind)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    other.closeAll(src)
    return vehicles.open(src, netId, kind)
end)

-- Searching another player: police Search, Rob, the admin menu's Open inventory. Who may is checked in server/searches.lua
lib.callback.register('city_inventory:openPlayer', function(source, target)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    if type(target) ~= 'number' then
        lib.print.warn(('Player %s asked to search an invalid player: %s'):format(src, target))
        return false, 'no_player'
    end

    other.closeAll(src)
    return searches.open(src, target)
end)

-- Opening the inventory with nothing else open shows the ground
lib.callback.register('city_inventory:openGround', function(source)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    other.closeAll(src)
    return drops.open(src)
end)

---@param src integer
---@param side unknown 'player', 'other' (stash, ground or a searched player) or 'offer' (the player's side of a trade)
---@param putting boolean items are going into it (an empty Ground panel becomes a drop)
---@return Inventory?
---@return string? reason
local function sideInventory(src, side, putting)
    if side == 'player' then return players.get(src) end
    if side == 'offer' then return trades.offer(src) end

    if side == 'other' then
        if drops.hasSession(src) then return drops.session(src, putting) end
        if searches.hasSession(src) then return searches.session(src) end
        return stashes.session(src)
    end

    return nil, 'invalid_slot'
end

---@param inventory Inventory
local function syncSide(inventory)
    if inventory.type == 'stash' then
        stashes.sync(inventory)
    elseif inventory.type == 'drop' then
        drops.sync(inventory)
    elseif inventory.type == 'player' then
        -- The searched player; the one searching is synced after
        players.sync(inventory.id --[[@as integer]])
    end
end

-- Moving items between the player's inventory and whatever is open next to it. With no target slot (an item dragged
-- out onto the ground), the server picks one.
lib.callback.register('city_inventory:transfer', function(source, fromSide, fromSlot, toSide, toSlot, count)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    -- With a shop open, the other side is the shop: items only come out of it, and are paid for
    if shops.session(src) then
        if fromSide ~= 'other' or toSide ~= 'player' then return false, 'cannot_sell' end

        local success
        success, reason = shops.buy(src, inventory, toInteger(fromSlot), toInteger(toSlot), count)
        if success then players.sync(src) end

        return success, reason
    end

    local from, fromReason = sideInventory(src, fromSide, false)
    local to, toReason = sideInventory(src, toSide, true)
    if not from or not to then return false, fromReason or toReason end

    fromSlot, toSlot = toInteger(fromSlot), toInteger(toSlot)
    local item = from:isSlot(fromSlot) and from.items[fromSlot]

    if toSlot == nil and item then
        toSlot = to:slotFor(item.name, item.metadata)
        if not toSlot then return false, 'inventory_full' end
    end

    local success
    success, reason = Inventory.transfer(from, fromSlot, to, toSlot, count)

    if success then
        for _, side in ipairs(from == to and { from } or { from, to }) do
            syncSide(side)
        end

        if fromSide == 'offer' or toSide == 'offer' then trades.changed(src) end
        players.sync(src)
    elseif reason == 'invalid_slot' or reason == 'invalid_count' then
        lib.print.warn(('Player %s sent an invalid transfer: %s %s -> %s %s x%s (%s)'):format(src, fromSide, fromSlot, toSide, toSlot, count, reason))
    end

    return success, reason
end)

RegisterNetEvent('city_inventory:server:closeOther', function()
    other.closeAll(source)
end)

lib.callback.register('city_inventory:requestTrade', function(source, target)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    other.closeAll(src)
    return trades.request(src, target)
end)

lib.callback.register('city_inventory:tradeCash', function(source, amount)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    return trades.setCash(src, amount)
end)

lib.callback.register('city_inventory:tradeAccept', function(source, accepted)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    return trades.accept(src, accepted)
end)

-- Going down or getting cuffed ends a trade straight away (the trade loop would catch it within a second)
AddEventHandler('qbx_core:server:onSetMetaData', function(key, _, value, src)
    if value and (key == 'isdead' or key == 'inlaststand' or key == 'ishandcuffed') then
        trades.cancel(src, 'trade_cancelled')
    end
end)

return other
