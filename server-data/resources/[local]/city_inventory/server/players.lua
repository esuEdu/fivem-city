-- Loaded player inventories, keyed by server id

local Inventory = require 'server.inventory'
local storage = require 'server.storage'
local weapons = require 'server.weapons'

local players = {}

---@type table<integer, Inventory>
local inventories = {}

---@type table<integer, table<integer, true>> server ids searching each player's inventory (server/searches.lua)
local viewers = {}

---Set by server/main.lua (left nil in unit tests). The cash item must always equal the player's cash in
---city_economy (mirrored by qbx_core); `expected` reads it, `mismatch` reports a difference.
---@type { item: string, isCash: fun(name: string): boolean, expected: fun(src: integer): integer?, mismatch: fun(src: integer, have: integer, want: integer) }?
players.cash = nil

---@param inventory Inventory
---@return integer
local function cashCount(inventory)
    local total = 0

    for _, item in pairs(inventory.items) do
        if players.cash.isCash(item.name) then total = total + item.count end
    end

    return total
end

---Puts the cash item back to what the ledger says. Reports it unless this is the first load.
---@param src integer
---@param inventory Inventory
---@param report boolean
local function reconcileCash(src, inventory, report)
    if not players.cash or inventory.cashBusy then return end

    local want = players.cash.expected(src)
    if not want then return end

    local have = cashCount(inventory)
    if have == want then return end

    -- Report a given mismatch once, even if the fix can't land (no free slot) and it shows up on every sync
    if report and inventory.cashReported ~= want then
        inventory.cashReported = want
        players.cash.mismatch(src, have, want)
    end

    inventory:set(players.cash.item, want)
end

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

    -- The saved inventory can be older than the ledger (crash between a payment and the next save): the ledger wins
    reconcileCash(src, inventory, false)
    inventory:takeChanges()

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

    -- Any path that changed the cash item without the ledger (a bug, a dupe) is undone here and reported
    reconcileCash(src, inventory, true)

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
