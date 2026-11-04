-- Finds any inventory from an ox_inventory `inv` argument: a player's server id, a stash id, or a table with id (and
-- owner, for stashes with one per character).

local players = require 'server.players'
local stashes = require 'server.stashes'

local inventories = {}

---@param inv unknown
---@return Inventory?
function inventories.resolve(inv)
    if type(inv) == 'table' and type(inv.id) == 'string' then
        return (stashes.get(inv.id, inv.owner))
    elseif type(inv) == 'string' and not tonumber(inv) then
        return (stashes.get(inv))
    end

    return (players.resolve(inv))
end

---Sends an inventory's changes to whoever sees it.
---@param inventory Inventory
function inventories.sync(inventory)
    if inventory.type == 'stash' then
        stashes.sync(inventory)
    else
        players.sync(inventory.id --[[@as integer]])
    end
end

return inventories
