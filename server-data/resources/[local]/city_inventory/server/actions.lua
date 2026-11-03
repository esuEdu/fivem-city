-- Requests from the player's own UI. The client only names slots; the server decides what happens.

local Items = require 'shared.items'
local Inventory = require 'server.inventory'
local players = require 'server.players'
local weapons = require 'server.weapons'

---@type table<integer, { second: integer, count: integer }>
local recentActions = {}

---@param src integer
---@return boolean
local function isRateLimited(src)
    local now = os.time()
    local entry = recentActions[src]

    if not entry or entry.second ~= now then
        entry = { second = now, count = 0 }
        recentActions[src] = entry
    end

    entry.count = entry.count + 1

    return entry.count > Config.ActionsPerSecond
end

---@param value unknown
---@return integer?
local function toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---Inventory of a player who is allowed to act on it right now.
---@param src integer
---@return Inventory? inventory
---@return string? reason
local function getActor(src)
    local inventory = players.get(src)
    if not inventory then return nil, 'busy' end

    if isRateLimited(src) then
        lib.print.warn(('Player %s sent more than %d inventory actions in a second'):format(src, Config.ActionsPerSecond))
        return nil, 'busy'
    end

    local player = exports.qbx_core:GetPlayer(src)
    local metadata = player and player.PlayerData.metadata

    if not metadata or metadata.isdead or metadata.inlaststand or metadata.ishandcuffed or Player(src).state.invBusy then
        return nil, 'busy'
    end

    return inventory
end

lib.callback.register('city_inventory:move', function(source, fromSlot, toSlot, count)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    local success
    success, reason = inventory:move(toInteger(fromSlot), toInteger(toSlot), count)

    if success then
        players.sync(src)
    elseif reason == 'invalid_slot' or reason == 'invalid_count' then
        lib.print.warn(('Player %s sent an invalid move: %s -> %s x%s (%s)'):format(src, fromSlot, toSlot, count, reason))
    end

    return success, reason
end)

lib.callback.register('city_inventory:use', function(source, slot)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    slot = toInteger(slot)
    local item = inventory:isSlot(slot) and inventory.items[slot]
    if not item then return false, 'invalid_slot' end

    -- Usable items are registered the Qbox way: exports.qbx_core:CreateUseableItem(name, fn)
    local onUse = exports.qbx_core:CanUseItem(item.name)
    if not onUse then return false, 'not_usable' end

    local definition = Items[item.name]

    -- The use function can return false to say the item was not used (and must not be consumed)
    if onUse(src, inventory:slotData(slot)) == false then
        return false, 'not_used'
    end

    local consume = Inventory.toCount(definition.consume)
    local current = inventory.items[slot]

    -- The use function may have moved or removed the item itself
    if consume and current and current.name == item.name then
        inventory:remove(item.name, math.min(consume, current.count), nil, slot)
    end

    players.sync(src)

    return true, definition.close
end)

lib.callback.register('city_inventory:equip', function(source, slot)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    return weapons.toggle(inventory, toInteger(slot))
end)

lib.callback.register('city_inventory:reload', function(source, serial, ammo)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    local success, result = weapons.reload(inventory, serial, ammo)
    players.sync(src)

    return success, result
end)

-- Sent while shooting (at most once a second) and when the weapon is put away.
-- Not rate-limited: ammo can only go down, so a spamming client can at most sync once per round it really had.
RegisterNetEvent('city_inventory:server:updateAmmo', function(serial, ammo)
    local src = source
    local inventory = players.get(src)
    if not inventory then return end

    if weapons.setAmmo(inventory, serial, ammo) then
        players.sync(src)
    end
end)

-- Put the weapon away when the player goes down or gets cuffed
AddEventHandler('qbx_core:server:onSetMetaData', function(key, _, value, src)
    if not value or (key ~= 'isdead' and key ~= 'inlaststand' and key ~= 'ishandcuffed') then return end

    local inventory = players.get(src)
    if not inventory or not inventory.equipped then return end

    weapons.unequip(inventory)
    TriggerClientEvent('city_inventory:client:disarm', src)
end)

AddEventHandler('playerDropped', function()
    recentActions[source] = nil
end)
