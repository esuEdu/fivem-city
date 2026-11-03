-- ox_inventory's client exports and events, for scripts written for it (qbx_hud, ox_fuel, ox_target, qbx_npwd,
-- mm_radio, qbx_police, ...). The ox_inventory resource forwards its exports here.

local Items = require 'shared.items'
local search = require 'shared.search'
local weightOf = require 'shared.weight'
local weapons = require 'client.weapons'
local other = require 'client.other'

local compat = {}

---@type fun(): table<integer, InventoryItem>
local getItems = function() return {} end

---@type fun()
local openOwn = function() end

---@type fun()
local closeOwn = function() end

---@param items fun(): table<integer, InventoryItem>
---@param open fun()
---@param close fun()
function compat.init(items, open, close)
    getItems, openOwn, closeOwn = items, open, close
end

---@param slot integer
---@param item InventoryItem
---@return table
local function slotData(slot, item)
    local definition = Items[item.name]

    return {
        slot = slot,
        name = item.name,
        count = item.count,
        metadata = item.metadata,
        label = definition.label,
        weight = weightOf(item),
    }
end

---ox_inventory's currentWeapon: the slot of the weapon in hand, plus its hash and ammo item.
---@return table?
local function currentWeapon()
    local serial = weapons.getSerial()
    if not serial then return end

    for slot, item in pairs(getItems()) do
        if item.metadata.serial == serial and Items[item.name].weapon then
            local data = slotData(slot, item)
            data.hash = joaat(item.name)
            data.ammo = Items[item.name].ammoname

            return data
        end
    end
end

weapons.onChange(function()
    TriggerEvent('ox_inventory:currentWeapon', currentWeapon())
end)

---@param names table<string, true>
---@return table<string, integer>
function compat.counts(names)
    local counts = {}

    for name in pairs(names) do
        counts[name] = search.count(getItems(), name)
    end

    return counts
end

---Fires ox_inventory's item events after slots changed. `before` holds the counts from compat.counts.
---@param before table<string, integer>
---@param changes table<integer, InventoryItem | false>
function compat.changed(before, changes)
    for name, oldCount in pairs(before) do
        local count = search.count(getItems(), name)

        if count ~= oldCount then
            local client = Items[name] and Items[name].client

            if client and client.add and count > oldCount then
                client.add(count)
            elseif client and client.remove and count < oldCount then
                client.remove(count)
            end

            TriggerEvent('ox_inventory:itemCount', name, count)
        end
    end

    local data = {}

    for slot, item in pairs(changes) do
        data[slot] = item and slotData(slot, item) or false
    end

    TriggerEvent('ox_inventory:updateInventory', data)
end

---@param reason string what the script asked for, for the warning
local function unsupported(reason)
    lib.print.warn(('A script asked for %s, which city_inventory does not have yet'):format(reason))
    lib.notify({ description = locale('error_unavailable'), type = 'error' })
end

-- Scripts like qbx_medical put the weapon away this way
AddEventHandler('ox_inventory:disarm', weapons.holster)

exports('Items', function(name)
    if name then
        return Items[name]
    end

    return Items
end)

exports('GetItemCount', function(name, metadata, strict)
    return search.count(getItems(), name, metadata, strict)
end)

exports('Search', function(kind, names, metadata)
    if kind ~= 'count' and kind ~= 'slots' then return end

    local items = getItems()

    return search.run(items, kind, names, metadata, function(slot)
        local item = items[slot]

        return { slot = slot, name = item.name, count = item.count, metadata = item.metadata, label = Items[item.name].label }
    end)
end)

exports('GetPlayerWeight', function()
    local total = 0

    for _, item in pairs(getItems()) do
        total = total + weightOf(item)
    end

    return total
end)

exports('getCurrentWeapon', currentWeapon)

exports('GetPlayerItems', function()
    local items = {}

    for slot, item in pairs(getItems()) do
        items[slot] = slotData(slot, item)
    end

    return items
end)

exports('openInventory', function(invType, data)
    if invType == 'player' and (data == nil or data == cache.serverId) then
        return openOwn()
    end

    if invType == 'stash' then
        return other.openStash(type(data) == 'table' and data.id or data)
    end

    if invType == 'shop' and type(data) == 'table' then
        return other.openShop(data.type, data.id)
    end

    unsupported(('openInventory(%s)'):format(invType))
end)

exports('closeInventory', function()
    closeOwn()
end)

exports('openNearbyInventory', function()
    unsupported('openNearbyInventory')
end)

---@type table<string, string>
local metadataLabels = {}

-- Extra metadata fields to show in the tooltip, e.g. qbx_idcard's citizen id and name
exports('displayMetadata', function(metadata, value)
    if type(metadata) == 'string' then
        if value then metadataLabels[metadata] = value end
    elseif type(metadata) == 'table' then
        for key, label in pairs(metadata) do
            -- Either { key = label } or an ordered list of { key = label }
            if type(label) == 'table' then
                for k, v in pairs(label) do metadataLabels[k] = v end
            else
                metadataLabels[key] = label
            end
        end
    end

    SendNUIMessage({ action = 'displayMetadata', labels = metadataLabels })
end)

---@return table<string, string>
function compat.metadataLabels()
    return metadataLabels
end

return compat
