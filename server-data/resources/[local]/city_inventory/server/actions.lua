-- Requests from the player's own UI. The client only names slots; the server decides what happens.

local Items = require 'shared.items'
local players = require 'server.players'
local use = require 'server.use'
local weapons = require 'server.weapons'
local components = require 'server.components'
local crafting = require 'server.crafting'

-- The client's progress bar and the server's clock don't start at the same moment
local CRAFT_TOLERANCE_MS = 300

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

lib.callback.register('city_inventory:use', function(source, slot, name)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    slot = toInteger(slot)
    local item = inventory:isSlot(slot) and inventory.items[slot]

    -- The item may have moved while the client played its progress bar
    if not item or (name ~= nil and item.name ~= name) then return false, 'invalid_slot' end

    local success, result = use.run(src, inventory, slot)
    players.sync(src)

    return success, result
end)

lib.callback.register('city_inventory:equip', function(source, slot)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    return weapons.toggle(inventory, toInteger(slot))
end)

lib.callback.register('city_inventory:reload', function(source, serial, ammo, clipHint)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    local success, result = weapons.reload(inventory, serial, ammo, clipHint)
    players.sync(src)

    return success, result
end)

---What dropping the item in `fromSlot` onto the one in `toSlot` does.
---@param inventory Inventory
---@param fromSlot unknown
---@param toSlot unknown
---@return 'load' | 'attach' | 'craft' | nil
---@return Recipe?
local function combination(inventory, fromSlot, toSlot)
    if fromSlot == toSlot then return end

    local from = inventory:isSlot(fromSlot) and inventory.items[fromSlot]
    local to = inventory:isSlot(toSlot) and inventory.items[toSlot]
    if not from or not to then return end

    local dragged, target = Items[from.name], Items[to.name]

    if target.weapon and dragged.ammo and target.ammoname and Items[target.ammoname] == dragged then
        return 'load'
    elseif target.weapon and dragged.component then
        return 'attach'
    end

    local recipe = crafting.recipeFor(from.name, to.name)
    if recipe then return 'craft', recipe end
end

---@type table<integer, { recipe: Recipe, startedAt: integer }>
local crafts = {}

-- Called before the client plays a recipe's progress bar, so the server can tell the wait really happened
lib.callback.register('city_inventory:startCraft', function(source, fromSlot, toSlot)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    local kind, recipe = combination(inventory, toInteger(fromSlot), toInteger(toSlot))
    if kind ~= 'craft' then return false, 'no_recipe' end

    crafts[src] = { recipe = recipe, startedAt = GetGameTimer() }

    return true, recipe.duration or 0
end)

---@param src integer
---@param recipe Recipe
---@return boolean
local function waitedFor(src, recipe)
    if not recipe.duration then return true end

    local pending = crafts[src]
    crafts[src] = nil

    return pending ~= nil and pending.recipe == recipe
        and GetGameTimer() - pending.startedAt >= recipe.duration - CRAFT_TOLERANCE_MS
end

-- Dropping one item onto another: ammo into a gun, an attachment onto a gun, or a recipe
lib.callback.register('city_inventory:combine', function(source, fromSlot, toSlot, count, clipHint)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    fromSlot, toSlot = toInteger(fromSlot), toInteger(toSlot)

    local kind, recipe = combination(inventory, fromSlot, toSlot)
    local success, result

    if kind == 'load' then
        success, result = weapons.load(inventory, toSlot, fromSlot, count, clipHint)
    elseif kind == 'attach' then
        success, result = components.attach(inventory, toSlot, fromSlot)
    elseif kind == 'craft' then
        if not waitedFor(src, recipe) then
            lib.print.warn(('Player %s finished crafting %s before its progress bar could have'):format(src, recipe.result[1]))
            return false, 'busy'
        end

        success, result = crafting.craft(inventory, recipe)
    else
        lib.print.warn(('Player %s tried to combine slots %s and %s, which do not combine (%s)'):format(src, fromSlot, toSlot, kind))
        return false, 'no_recipe'
    end

    players.sync(src)

    return success, result
end)

lib.callback.register('city_inventory:unload', function(source, slot)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end

    local success, result = weapons.unload(inventory, toInteger(slot))
    players.sync(src)

    return success, result
end)

lib.callback.register('city_inventory:detach', function(source, slot, name)
    local src = source
    local inventory, reason = getActor(src)
    if not inventory then return false, reason end
    if type(name) ~= 'string' then return false, 'not_component' end

    local success
    success, reason = components.detach(inventory, toInteger(slot), name)
    players.sync(src)

    return success, reason
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

-- ox_inventory's opened/closedInventory events, which qbx_hud uses to hide while the inventory is open.
-- Only the player's own HUD reacts, so a client sending this is harmless.
RegisterNetEvent('city_inventory:server:setOpen', function(isOpen)
    local src = source
    if not players.get(src) then return end

    TriggerEvent(isOpen == true and 'ox_inventory:openedInventory' or 'ox_inventory:closedInventory', src)
end)

-- The client put the weapon away itself; unequipping only ever takes something away, so no other checks are needed
RegisterNetEvent('city_inventory:server:holster', function()
    local inventory = players.get(source)
    if not inventory then return end

    weapons.unequip(inventory)
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
    crafts[source] = nil
end)
