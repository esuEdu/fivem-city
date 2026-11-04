-- Stashes registered by other scripts (ox_inventory's RegisterStash): job lockers, house storage, ...
-- A stash is loaded from the database the first time something opens or changes it, and dropped from memory again once
-- nobody has it open and it's saved.

local Inventory = require 'server.inventory'
local storage = require 'server.storage'
local hooks = require 'server.hooks'
local access = require 'server.access'

local stashes = {}

---@class StashDefinition
---@field id string
---@field label string
---@field slots integer
---@field maxWeight integer
---@field owner? true | string true: one per character, string: that owner's, nil: shared
---@field groups? table<string, integer> job or gang -> lowest grade allowed
---@field coords? vector3[] where it can be opened from
---@field temporary? boolean kept in memory only, never saved (trunks of cars nobody owns)

---@class StashSession
---@field inventory Inventory
---@field definition StashDefinition
---@field coords vector3 where the player stood when it opened

---@type table<string, StashDefinition>
local definitions = {}

---@type table<string, Inventory> by inventory id
local loaded = {}

---@type table<string, promise> inventory ids being read from the database
local loading = {}

---@type table<Inventory, table<integer, true>> server ids that have the stash open
local viewers = {}

---@type table<integer, StashSession>
local sessions = {}

function stashes.register(id, label, slots, maxWeight, owner, groups, coords, temporary)
    slots, maxWeight = math.tointeger(tonumber(slots)), math.tointeger(tonumber(maxWeight))

    if type(id) ~= 'string' or not slots or slots < 1 or not maxWeight or maxWeight < 0 then
        return lib.print.warn(('Invalid stash registration from %s: %s'):format(GetInvokingResource(), id))
    end

    definitions[id] = {
        id = id,
        label = type(label) == 'string' and label or id,
        slots = slots,
        maxWeight = maxWeight,
        owner = (owner == true or type(owner) == 'string') and owner or nil,
        groups = access.toGroups(groups),
        coords = access.toCoords(coords),
        temporary = temporary == true,
    }

    -- e.g. a car someone just bought: its trunk starts being saved
    if loaded[id] then loaded[id].temporary = temporary == true end
end

---The ox_inventory id of one stash: id, or id:owner for stashes that have an owner.
---@param definition StashDefinition
---@param owner? string citizenid, for stashes with one per character
---@return string?
local function inventoryIdFor(definition, owner)
    if definition.owner == true then
        return type(owner) == 'string' and ('%s:%s'):format(definition.id, owner) or nil
    elseif definition.owner then
        return ('%s:%s'):format(definition.id, definition.owner)
    end

    return definition.id
end

---@param id unknown a stash id, or the full inventory id (policelocker:ABC123)
---@param owner? unknown
---@return StashDefinition?
---@return string? owner
local function findDefinition(id, owner)
    if type(id) ~= 'string' then return end
    if definitions[id] then return definitions[id], owner end

    local baseId, idOwner = id:match('^(.*):([^:]+)$')

    return baseId and definitions[baseId], idOwner
end

---The stash's inventory, loaded from the database if needed. Yields.
---@param id unknown
---@param owner? unknown citizenid, for stashes with one per character
---@return Inventory?
---@return StashDefinition?
function stashes.get(id, owner)
    local definition
    definition, owner = findDefinition(id, owner)
    if not definition then return end

    local inventoryId = inventoryIdFor(definition, owner)
    if not inventoryId then return end

    if loaded[inventoryId] then return loaded[inventoryId], definition end

    if loading[inventoryId] then
        Citizen.Await(loading[inventoryId])
        return loaded[inventoryId], definition
    end

    local done = promise.new()
    loading[inventoryId] = done

    local key = ('stash:%s'):format(inventoryId)
    local inventory = Inventory.new(key, definition.slots, definition.maxWeight, not definition.temporary and storage.load(key) or nil)
    inventory.type = 'stash'
    inventory.id = inventoryId
    inventory.temporary = definition.temporary

    loaded[inventoryId] = inventory
    viewers[inventory] = {}
    loading[inventoryId] = nil
    done:resolve()

    return inventory, definition
end

---@param src integer
---@param id unknown
---@param force? boolean the calling script already decided the player may open it (forceOpenInventory)
---@return boolean success
---@return string? reason
function stashes.open(src, id, force)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'busy' end

    local definition, owner = findDefinition(id)
    if not definition then return false, 'no_stash' end

    if not force then
        if not access.inGroup(src, definition.groups) then return false, 'no_access' end
        if not access.isNear(src, definition.coords, Config.StashDistance) then return false, 'too_far' end
    end

    -- Stashes with one per character always open the player's own
    local inventory = stashes.get(definition.id, definition.owner == true and player.PlayerData.citizenid or owner)
    if not inventory then return false, 'no_stash' end

    if not force and not hooks.run('openInventory', { source = src, inventoryId = inventory.id, inventoryType = 'stash' }) then
        return false, 'no_access'
    end

    stashes.close(src)

    sessions[src] = { inventory = inventory, definition = definition, coords = GetEntityCoords(GetPlayerPed(src)) }
    viewers[inventory][src] = true

    TriggerClientEvent('city_inventory:client:openOther', src, {
        id = inventory.id,
        label = definition.label,
        slots = inventory.slotCount,
        maxWeight = inventory.maxWeight,
        weight = inventory.weight,
        items = inventory.items,
    })

    return true
end

---The stash the player has open, if they may still use it (same job and still standing next to it).
---@param src integer
---@return Inventory? inventory
---@return string? reason
function stashes.session(src)
    local session = sessions[src]
    if not session then return nil, 'stash_closed' end

    local position = GetEntityCoords(GetPlayerPed(src))

    if #(position - session.coords) > Config.StashDistance or not access.inGroup(src, session.definition.groups) then
        stashes.close(src)
        TriggerClientEvent('city_inventory:client:closeOther', src)
        return nil, 'stash_closed'
    end

    return session.inventory
end

---@param src integer
function stashes.close(src)
    local session = sessions[src]
    if not session then return end

    sessions[src] = nil
    viewers[session.inventory][src] = nil
end

---Sends the slots changed since the last sync to everyone who has the stash open.
---@param inventory Inventory
function stashes.sync(inventory)
    local changes = inventory:takeChanges()
    if not next(changes) then return end

    for src in pairs(viewers[inventory] or {}) do
        TriggerClientEvent('city_inventory:client:updateOther', src, changes, inventory.weight)
    end
end

---Saves changed stashes and forgets the ones nobody has open.
---@param wait? boolean false while the resource is stopping
function stashes.saveAll(wait)
    local rows = {}

    for _, inventory in pairs(loaded) do
        if inventory.dirty and not inventory.temporary then
            rows[#rows + 1] = { owner = inventory.owner, entries = inventory:serialize() }
            inventory.dirty = false
        end
    end

    storage.save(rows, wait)
    if wait == false then return end

    -- Only after the save finished, so loading one again reads what was just written
    for inventoryId, inventory in pairs(loaded) do
        if not inventory.dirty and not next(viewers[inventory]) then
            loaded[inventoryId] = nil
            viewers[inventory] = nil
        end
    end
end

return stashes
