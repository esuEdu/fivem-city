-- Loaded player inventories, keyed by server id

local Inventory = require 'server.inventory'
local storage = require 'server.storage'

local players = {}

---@type table<integer, Inventory>
local inventories = {}

---@param src integer
---@return Inventory?
function players.get(src)
    return inventories[src]
end

---@param src integer
---@param citizenid string
function players.load(src, citizenid)
    if inventories[src] then return end

    local inventory = Inventory.new(citizenid, Config.Slots, Config.MaxWeight, storage.load(citizenid))

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
