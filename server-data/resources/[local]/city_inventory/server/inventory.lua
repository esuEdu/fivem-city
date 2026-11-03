-- One inventory held in memory. No FiveM natives here: callers decide who may change it and sync the changes.

local Items = require 'shared.items'
local search = require 'shared.search'

---@class Inventory
---@field owner string
---@field slotCount integer
---@field maxWeight integer
---@field weight integer
---@field items table<integer, InventoryItem>
---@field unknown table[] saved entries that can't be loaded (item no longer defined, bad slot), kept so they aren't lost
---@field changed table<integer, true> slots changed since the last takeChanges()
---@field dirty boolean changed since the last save
local Inventory = {}
Inventory.__index = Inventory

---@param value unknown
---@return integer? count a whole number of at least 1
function Inventory.toCount(value)
    value = tonumber(value)
    if not value or value < 1 or value ~= math.floor(value) or value == math.huge then return end

    return math.tointeger(value)
end

local toCount = Inventory.toCount

local function generateSerial()
    return lib.string.random('11AAA111AA1')
end

---@param owner string citizenid
---@param slotCount integer
---@param maxWeight integer
---@param saved? { slot: integer, name: string, count: integer, metadata?: table }[]
---@return Inventory
function Inventory.new(owner, slotCount, maxWeight, saved)
    local self = setmetatable({
        owner = owner,
        slotCount = slotCount,
        maxWeight = maxWeight,
        weight = 0,
        items = {},
        unknown = {},
        changed = {},
        dirty = false,
    }, Inventory)

    for _, entry in ipairs(saved or {}) do
        local slot, count = math.tointeger(entry.slot), toCount(entry.count)

        if Items[entry.name] and self:isSlot(slot) and count and not self.items[slot] then
            self.items[slot] = { name = entry.name, count = count, metadata = entry.metadata or {} }
            self.weight = self.weight + self:itemWeight(entry.name, count)
        else
            self.unknown[#self.unknown + 1] = entry
        end
    end

    if #self.unknown > 0 then
        lib.print.warn(('Inventory %s has %d saved entries that could not be loaded (undefined item or bad slot); they are kept in the database'):format(owner, #self.unknown))
    end

    return self
end

---@param slot unknown
---@return boolean
function Inventory:isSlot(slot)
    return math.type(slot) == 'integer' and slot >= 1 and slot <= self.slotCount
end

---@param name string
---@param count integer
---@return integer
function Inventory:itemWeight(name, count)
    return Items[name].weight * count
end

---@param slot integer
---@param item? InventoryItem
function Inventory:setSlot(slot, item)
    self.items[slot] = item
    self.changed[slot] = true
    self.dirty = true
end

---@param limit integer
---@return integer[]
function Inventory:freeSlots(limit)
    local slots = {}

    for slot = 1, self.slotCount do
        if not self.items[slot] then
            slots[#slots + 1] = slot
            if #slots == limit then break end
        end
    end

    return slots
end

---@param name string
---@param metadata table
---@return integer?
function Inventory:findStack(name, metadata)
    for slot = 1, self.slotCount do
        local item = self.items[slot]

        if item and item.name == name and lib.table.matches(item.metadata, metadata) then
            return slot
        end
    end
end

---@param name string
---@param count integer
---@param metadata? table
---@return boolean
function Inventory:canFit(name, count, metadata)
    local definition = Items[name]
    count = toCount(count)
    if not definition or not count then return false end
    if self.weight + self:itemWeight(name, count) > self.maxWeight then return false end

    if definition.stack then
        return self:findStack(name, metadata or {}) ~= nil or #self:freeSlots(1) == 1
    end

    return #self:freeSlots(count) == count
end

---@param name string
---@param count integer
---@param metadata? table
---@param slot? integer
---@return boolean success
---@return string? reason
function Inventory:add(name, count, metadata, slot)
    local definition = Items[name]
    count = toCount(count)

    if not definition then return false, 'invalid_item' end
    if not count then return false, 'invalid_count' end
    if metadata ~= nil and type(metadata) ~= 'table' then return false, 'invalid_metadata' end
    if slot ~= nil and not self:isSlot(slot) then return false, 'invalid_slot' end
    if self.weight + self:itemWeight(name, count) > self.maxWeight then return false, 'inventory_full' end

    metadata = metadata or {}

    if definition.stack then
        slot = slot or self:findStack(name, metadata) or self:freeSlots(1)[1]
        if not slot then return false, 'inventory_full' end

        local current = self.items[slot]
        if current and not (current.name == name and lib.table.matches(current.metadata, metadata)) then
            return false, 'slot_occupied'
        end

        self:setSlot(slot, {
            name = name,
            count = (current and current.count or 0) + count,
            metadata = current and current.metadata or lib.table.deepclone(metadata),
        })
    else
        local slots

        if slot then
            if count ~= 1 or self.items[slot] then return false, 'slot_occupied' end
            slots = { slot }
        else
            slots = self:freeSlots(count)
            if #slots < count then return false, 'inventory_full' end
        end

        for i = 1, count do
            local itemMetadata = lib.table.deepclone(metadata)

            if definition.weapon then
                itemMetadata.serial = itemMetadata.serial or generateSerial()
                itemMetadata.ammo = definition.ammoname and (itemMetadata.ammo or 0) or nil
            end

            self:setSlot(slots[i], { name = name, count = 1, metadata = itemMetadata })
        end
    end

    self.weight = self.weight + self:itemWeight(name, count)

    return true
end

---@param name string
---@param count integer
---@param metadata? table | string
---@param slot? integer only take from this slot
---@return boolean success
---@return string? reason
function Inventory:remove(name, count, metadata, slot)
    count = toCount(count)

    if not Items[name] then return false, 'invalid_item' end
    if not count then return false, 'invalid_count' end

    local slots

    if slot ~= nil then
        local item = self:isSlot(slot) and self.items[slot]
        if not item or item.name ~= name or not search.matches(item.metadata, metadata) then
            return false, 'not_enough_items'
        end
        slots = { slot }
    else
        slots = search.slots(self.items, name, metadata)
    end

    local available = 0

    for _, s in ipairs(slots) do
        available = available + self.items[s].count
    end

    if available < count then return false, 'not_enough_items' end

    local remaining = count

    for _, s in ipairs(slots) do
        local item = self.items[s]
        local taken = math.min(item.count, remaining)
        remaining = remaining - taken

        self:setSlot(s, item.count > taken and { name = name, count = item.count - taken, metadata = item.metadata } or nil)

        if remaining == 0 then break end
    end

    self.weight = self.weight - self:itemWeight(name, count)

    return true
end

---Adds or removes items so the player has exactly `count`.
---@param name string
---@param count integer
---@param metadata? table
---@return boolean success
---@return string? reason
function Inventory:set(name, count, metadata)
    count = tonumber(count)
    if not Items[name] then return false, 'invalid_item' end
    if not count or count < 0 or count ~= math.floor(count) then return false, 'invalid_count' end

    local current = search.count(self.items, name, metadata)

    if count > current then
        return self:add(name, count - current, metadata)
    elseif count < current then
        return self:remove(name, current - count, metadata)
    end

    return true
end

---Moves `count` items between slots: into an empty slot (split), onto the same item (stack), or swaps two slots.
---@param fromSlot integer
---@param toSlot integer
---@param count? integer defaults to the whole stack
---@return boolean success
---@return string? reason
function Inventory:move(fromSlot, toSlot, count)
    if not self:isSlot(fromSlot) or not self:isSlot(toSlot) or fromSlot == toSlot then return false, 'invalid_slot' end

    local from = self.items[fromSlot]
    if not from then return false, 'invalid_slot' end

    count = count == nil and from.count or toCount(count)
    if not count or count > from.count then return false, 'invalid_count' end

    local to = self.items[toSlot]
    local rest = count < from.count and { name = from.name, count = from.count - count, metadata = from.metadata } or nil

    if not to then
        self:setSlot(toSlot, { name = from.name, count = count, metadata = rest and lib.table.deepclone(from.metadata) or from.metadata })
        self:setSlot(fromSlot, rest)
    elseif to.name == from.name and Items[from.name].stack and lib.table.matches(to.metadata, from.metadata) then
        self:setSlot(toSlot, { name = to.name, count = to.count + count, metadata = to.metadata })
        self:setSlot(fromSlot, rest)
    elseif not rest then
        self:setSlot(toSlot, from)
        self:setSlot(fromSlot, to)
    else
        return false, 'slot_occupied'
    end

    return true
end

---@param keep? string | string[] item names to leave in the inventory
function Inventory:clear(keep)
    local kept = {}

    for _, name in ipairs(type(keep) == 'table' and keep or { keep }) do
        kept[name] = true
    end

    for slot, item in pairs(self.items) do
        if not kept[item.name] then
            self.weight = self.weight - self:itemWeight(item.name, item.count)
            self:setSlot(slot, nil)
        end
    end
end

---Slot contents in the shape ox_inventory exports return.
---@param slot integer
---@return table?
function Inventory:slotData(slot)
    local item = self.items[slot]
    if not item then return end

    local definition = Items[item.name]

    return {
        slot = slot,
        name = item.name,
        count = item.count,
        metadata = item.metadata,
        label = definition.label,
        weight = self:itemWeight(item.name, item.count),
        stack = definition.stack,
        close = definition.close,
    }
end

---@return table<integer, InventoryItem | false> changes slot -> new contents, false when emptied
function Inventory:takeChanges()
    local changes = {}

    for slot in pairs(self.changed) do
        changes[slot] = self.items[slot] or false
    end

    self.changed = {}

    return changes
end

---@return table[] entries to store, including the unknown ones
function Inventory:serialize()
    local entries = {}

    for slot, item in pairs(self.items) do
        entries[#entries + 1] = { slot = slot, name = item.name, count = item.count, metadata = item.metadata }
    end

    for _, entry in ipairs(self.unknown) do
        entries[#entries + 1] = entry
    end

    return entries
end

return Inventory
