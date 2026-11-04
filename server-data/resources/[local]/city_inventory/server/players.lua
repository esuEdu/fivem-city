-- Loaded player inventories, keyed by server id

local Inventory = require 'server.inventory'
local storage = require 'server.storage'
local weapons = require 'server.weapons'

local players = {}

---@type table<integer, Inventory>
local inventories = {}

---@type table<integer, table<integer, true>> server ids searching each player's inventory (server/searches.lua)
local viewers = {}

---Who has this player's inventory open next to their own; add and remove ids in the returned table.
---@param src integer
---@return table<integer, true>
function players.viewers(src)
    viewers[src] = viewers[src] or {}

    return viewers[src]
end

---@param src integer
---@return Inventory?
function players.get(src)
    return inventories[src]
end

---An ox_inventory `inv` argument: a player's server id, or the table GetInventory returned.
---@param inv unknown
---@return Inventory? inventory
---@return integer? src
function players.resolve(inv)
    if type(inv) == 'table' then
        inv = inv.id
    end

    local src = math.tointeger(tonumber(inv))

    return src and inventories[src], src
end

---@param src integer
---@param citizenid string
function players.load(src, citizenid)
    if inventories[src] then return end

    local inventory = Inventory.new(citizenid, Config.Slots, Config.MaxWeight, storage.load(citizenid))
    inventory.id = src

    -- The player may have left while the database was loading
    if not GetPlayerName(src) then return end

    inventories[src] = inventory

    TriggerClientEvent('city_inventory:client:setInventory', src, inventory.items, inventory.weight)
end

---@param src integer
function players.unload(src)
    local inventory = inventories[src]
    if not inventory then return end

    inventories[src] = nil

    for viewer in pairs(viewers[src] or {}) do
        TriggerClientEvent('city_inventory:client:closeOther', viewer, 'search_closed')
    end

    viewers[src] = nil

    if inventory.dirty then
        storage.save({ { owner = inventory.owner, entries = inventory:serialize() } })
    end
end

---Sends the slots changed since the last sync to the player.
---@param src integer
function players.sync(src)
    local inventory = inventories[src]
    if not inventory then return end

    local changes = inventory:takeChanges()

    if next(changes) then
        TriggerClientEvent('city_inventory:client:updateSlots', src, changes, inventory.weight)

        for viewer in pairs(viewers[src] or {}) do
            TriggerClientEvent('city_inventory:client:updateOther', viewer, changes, inventory.weight)
        end
    end

    if weapons.check(inventory) then
        TriggerClientEvent('city_inventory:client:disarm', src)
    end
end

---@param wait? boolean
function players.saveAll(wait)
    local rows = {}

    for _, inventory in pairs(inventories) do
        if inventory.dirty then
            rows[#rows + 1] = { owner = inventory.owner, entries = inventory:serialize() }
            inventory.dirty = false
        end
    end

    storage.save(rows, wait)
end

return players
