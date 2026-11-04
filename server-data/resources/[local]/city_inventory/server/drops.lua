-- Items on the ground. A drop is a small inventory with a place in the world (a bag prop on every client); it lives in
-- memory only and goes away when it's empty or after Config.DropMinutes, like ox_inventory's drops.

local Inventory = require 'server.inventory'

local drops = {}

---@class Drop
---@field inventory Inventory
---@field coords vector3
---@field createdAt integer os.time()

---@class GroundSession
---@field id? string the drop the player has open; nil while the Ground panel is still empty
---@field coords vector3 where the player stood when it opened

---@type table<string, Drop>
local list = {}

---@type table<string, table<integer, true>> server ids that have a drop open
local viewers = {}

---@type table<integer, GroundSession>
local sessions = {}

local nextId = 0

---@param position vector3
---@return string? id
---@return Drop?
local function nearest(position)
    local bestId, best, bestDistance

    for id, drop in pairs(list) do
        local distance = #(position - drop.coords)

        if distance <= Config.DropDistance and (not bestDistance or distance < bestDistance) then
            bestId, best, bestDistance = id, drop, distance
        end
    end

    return bestId, best
end

---@param coords vector3
---@param slots? integer
---@param maxWeight? integer
---@return Inventory
function drops.create(coords, slots, maxWeight)
    nextId = nextId + 1
    local id = ('drop-%d'):format(nextId)

    local inventory = Inventory.new(id, slots or Config.DropSlots, maxWeight or Config.DropMaxWeight)
    inventory.type = 'drop'
    inventory.id = id

    list[id] = { inventory = inventory, coords = vec3(coords.x, coords.y, coords.z), createdAt = os.time() }
    viewers[id] = {}

    TriggerClientEvent('city_inventory:client:addDrop', -1, id, list[id].coords)

    return inventory
end

---@param id string
function drops.remove(id)
    if not list[id] then return end

    for src in pairs(viewers[id]) do
        sessions[src] = nil
        TriggerClientEvent('city_inventory:client:closeOther', src)
    end

    list[id] = nil
    viewers[id] = nil

    TriggerClientEvent('city_inventory:client:removeDrop', -1, id)
end

---@return table<string, vector3>
function drops.all()
    local result = {}

    for id, drop in pairs(list) do
        result[id] = drop.coords
    end

    return result
end

---@param id string
---@return Inventory?
function drops.get(id)
    return list[id] and list[id].inventory
end

---Opens the Ground panel: the nearest drop, or an empty one that becomes a drop when something is put in it.
---@param src integer
---@return boolean success
function drops.open(src)
    drops.close(src)

    local position = GetEntityCoords(GetPlayerPed(src))
    local id, drop = nearest(position)

    sessions[src] = { id = id, coords = position }
    if id then viewers[id][src] = true end

    local inventory = drop and drop.inventory

    TriggerClientEvent('city_inventory:client:openOther', src, {
        id = id or 'ground',
        kind = 'drop',
        label = locale('ui_ground'),
        slots = inventory and inventory.slotCount or Config.DropSlots,
        maxWeight = inventory and inventory.maxWeight or Config.DropMaxWeight,
        weight = inventory and inventory.weight or 0,
        items = inventory and inventory.items or {},
    })

    return true
end

---@param src integer
---@return boolean
function drops.hasSession(src)
    return sessions[src] ~= nil
end

---The drop the player has open, if they're still next to it. An empty Ground panel becomes a drop at the player's
---feet when `create` is set (something is being put down).
---@param src integer
---@param create? boolean
---@return Inventory? inventory
---@return string? reason
function drops.session(src, create)
    local session = sessions[src]
    if not session then return nil, 'stash_closed' end

    local position = GetEntityCoords(GetPlayerPed(src))
    local anchor = session.id and list[session.id] and list[session.id].coords or session.coords

    if #(position - anchor) > Config.DropDistance then
        drops.close(src)
        TriggerClientEvent('city_inventory:client:closeOther', src)
        return nil, 'stash_closed'
    end

    if session.id then return list[session.id].inventory end
    if not create then return nil, 'invalid_slot' end

    local inventory = drops.create(position)
    session.id = inventory.id
    viewers[inventory.id][src] = true

    return inventory
end

---@param src integer
function drops.close(src)
    local session = sessions[src]
    if not session then return end

    sessions[src] = nil
    if session.id and viewers[session.id] then viewers[session.id][src] = nil end
end

---Sends a drop's changes to everyone who has it open; an empty drop is removed.
---@param inventory Inventory
function drops.sync(inventory)
    local changes = inventory:takeChanges()
    local id = inventory.id --[[@as string]]

    if not next(inventory.items) then
        return drops.remove(id)
    end

    if not next(changes) then return end

    for src in pairs(viewers[id] or {}) do
        TriggerClientEvent('city_inventory:client:updateOther', src, changes, inventory.weight)
    end
end

---Puts items on the ground at `coords` (ox_inventory's CustomDrop). Items that don't fit are left out and logged.
---@param items { [1]: string, [2]: integer, [3]?: table }[] | { name: string, count: integer, metadata?: table }[]
---@param coords vector3
---@param slots? integer
---@param maxWeight? integer
---@return string? id
function drops.custom(items, coords, slots, maxWeight)
    if type(items) ~= 'table' or not coords then return end

    local inventory = drops.create(coords, slots, maxWeight)

    for _, entry in ipairs(items) do
        local name, count, metadata = entry.name or entry[1], entry.count or entry[2], entry.metadata or entry[3]
        local success, reason = inventory:add(name, count or 1, metadata)

        if not success then
            lib.print.warn(('Drop %s: could not add %sx %s (%s)'):format(inventory.id, count, name, reason))
        end
    end

    inventory:takeChanges()

    if not next(inventory.items) then
        drops.remove(inventory.id --[[@as string]])
        return
    end

    return inventory.id --[[@as string]]
end

CreateThread(function()
    while true do
        Wait(60000)

        local expired = os.time() - Config.DropMinutes * 60

        for id, drop in pairs(list) do
            if drop.createdAt < expired then drops.remove(id) end
        end
    end
end)

lib.callback.register('city_inventory:getDrops', function()
    return drops.all()
end)

return drops
