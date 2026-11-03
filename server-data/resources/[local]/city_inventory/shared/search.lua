-- Item lookups shared by the server inventory and the client's copy of it

---@class InventoryItem
---@field name string
---@field count integer
---@field metadata table

local Items = require 'shared.items'

local search = {}

---Name as stored in inventories, so callers can use any case (WEAPON_PISTOL / weapon_pistol).
---@param name string
---@return string
local function canonical(name)
    local definition = Items[name]
    return definition and definition.name or name
end

---@param metadata? table
---@param filter? table | string
---@param strict? boolean
---@return boolean
function search.matches(metadata, filter, strict)
    if filter == nil then return true end

    -- ox_inventory treats a string filter as metadata.type
    if type(filter) == 'string' then
        filter = { type = filter }
    end

    metadata = metadata or {}

    if strict then
        return lib.table.matches(metadata, filter)
    end

    for key, value in pairs(filter) do
        if not lib.table.matches(metadata[key], value) then
            return false
        end
    end

    return true
end

---@param slots table<integer, InventoryItem>
---@param name string
---@param filter? table | string
---@param strict? boolean
---@return integer
function search.count(slots, name, filter, strict)
    local total = 0
    name = canonical(name)

    for _, item in pairs(slots) do
        if item.name == name and search.matches(item.metadata, filter, strict) then
            total = total + item.count
        end
    end

    return total
end

---@param slots table<integer, InventoryItem>
---@param name string
---@param filter? table | string
---@param strict? boolean
---@return integer[] slot numbers in ascending order
function search.slots(slots, name, filter, strict)
    local found = {}
    name = canonical(name)

    for slot, item in pairs(slots) do
        if item.name == name and search.matches(item.metadata, filter, strict) then
            found[#found + 1] = slot
        end
    end

    table.sort(found)

    return found
end

---ox_inventory's Search: one result for a single item name, a table keyed by name for a list.
---@param slots table<integer, InventoryItem>
---@param kind 'count' | 'slots'
---@param names string | string[]
---@param filter? table | string
---@param toSlotData fun(slot: integer): table
---@return any
function search.run(slots, kind, names, filter, toSlotData)
    local function find(name)
        if kind == 'count' then
            return search.count(slots, name, filter)
        end

        local result = {}

        for _, slot in ipairs(search.slots(slots, name, filter)) do
            result[#result + 1] = toSlotData(slot)
        end

        return result
    end

    if type(names) ~= 'table' then
        return find(names)
    end

    local results = {}

    for _, name in ipairs(names) do
        results[name] = find(name)
    end

    return results
end

return search
