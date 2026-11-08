-- Shops: the ones in data/shops.lua and those other scripts register (ox_inventory's RegisterShop, e.g. the ambulance
-- armory). The player drags an item out of the shop panel to buy it; prices, stock, licences and grades are checked here.

local Items = require 'shared.items'
local search = require 'shared.search'
local access = require 'server.access'

local shops = {}

---@class ShopItem
---@field name string
---@field price integer
---@field count? integer stock, nil = unlimited
---@field metadata? table
---@field license? string qbx licence the buyer needs (metadata.licences)
---@field grade? integer lowest job grade, on top of the shop's groups
---@field currency? string an item paid with instead of money

---@class ShopDefinition
---@field type string
---@field label string
---@field groups? table<string, integer>
---@field items ShopItem[]
---@field coords? vector3[] where it can be opened; nil for shops opened from props (vending machines)

---@class ShopSession
---@field shop ShopDefinition
---@field key string the shop instance (type and location), for stock
---@field coords vector3 where the player stood when it opened

---@type table<string, ShopDefinition>
local definitions = {}

---@type table<string, table<integer, integer>> stock left per shop instance and slot
local stock = {}

---@type table<string, table<integer, true>> server ids that have a shop instance open
local viewers = {}

---@type table<integer, ShopSession>
local sessions = {}

---@param shopType string
---@param data table ox_inventory's shop format: name, groups, inventory, locations
function shops.register(shopType, data)
    if type(shopType) ~= 'string' or type(data) ~= 'table' or type(data.inventory) ~= 'table' then
        return lib.print.warn(('Invalid shop registration from %s: %s'):format(GetInvokingResource() or 'data/shops.lua', shopType))
    end

    local items = {}

    for _, entry in ipairs(data.inventory) do
        local definition = Items[entry.name]
        local price = math.tointeger(tonumber(entry.price))

        if definition and price and price >= 0 then
            items[#items + 1] = {
                name = definition.name,
                price = price,
                count = math.tointeger(tonumber(entry.count)),
                metadata = type(entry.metadata) == 'table' and entry.metadata or nil,
                license = entry.license,
                grade = math.tointeger(tonumber(entry.grade)),
                currency = entry.currency and Items[entry.currency] and Items[entry.currency].name or nil,
            }
        else
            lib.print.warn(('Shop %s: item %s is not defined or has no price; left out'):format(shopType, entry.name))
        end
    end

    definitions[shopType] = {
        type = shopType,
        label = data.name or shopType,
        groups = access.toGroups(data.groups),
        items = items,
        coords = access.toCoords(data.locations),
    }

    -- Re-registering (a script restarting) refills the stock
    for key in pairs(stock) do
        if key:find(('%s:'):format(shopType), 1, true) == 1 then stock[key] = nil end
    end
end

---@param key string
---@param shop ShopDefinition
---@return table<integer, integer>
local function stockOf(key, shop)
    if not stock[key] then
        stock[key] = {}

        for slot, item in ipairs(shop.items) do
            stock[key][slot] = item.count
        end
    end

    return stock[key]
end

---The shop's items as inventory slots for the panel, with price and stock.
---@param key string
---@param shop ShopDefinition
---@return table<integer, table>
local function slotsFor(key, shop)
    local left = stockOf(key, shop)
    local slots = {}

    for slot, item in ipairs(shop.items) do
        slots[slot] = { name = item.name, count = 1, metadata = item.metadata or {}, price = item.price, currency = item.currency, stock = left[slot] }
    end

    return slots
end

---@param src integer
---@param shopType unknown
---@param id unknown which location, for shops with several
---@return boolean success
---@return string? reason
function shops.open(src, shopType, id)
    local shop = type(shopType) == 'string' and definitions[shopType]
    if not shop then return false, 'no_shop' end
    if not access.inGroup(src, shop.groups) then return false, 'no_access' end

    local coords = shop.coords
    id = math.tointeger(tonumber(id))

    if coords then
        -- A location number narrows it to that spot; otherwise any of the shop's locations will do
        if id and coords[id] then coords = { coords[id] } end
        if not access.isNear(src, coords, Config.ShopDistance) then return false, 'too_far' end
    end

    local key = ('%s:%s'):format(shop.type, id or 1)

    shops.close(src)

    sessions[src] = { shop = shop, key = key, coords = GetEntityCoords(GetPlayerPed(src)) }
    viewers[key] = viewers[key] or {}
    viewers[key][src] = true

    TriggerClientEvent('city_inventory:client:openOther', src, {
        id = key,
        kind = 'shop',
        label = shop.label,
        slots = #shop.items,
        items = slotsFor(key, shop),
    })

    return true
end

---@param src integer
---@return ShopSession?
function shops.session(src)
    return sessions[src]
end

---@param src integer
function shops.close(src)
    local session = sessions[src]
    if not session then return end

    sessions[src] = nil
    viewers[session.key][src] = nil
end

---@param src integer
---@param item ShopItem
---@param total integer
---@param inventory Inventory
---@return boolean paid
---@return string? account the money account it was paid from, for a refund
local function pay(src, item, total, inventory)
    if total == 0 then return true end

    if item.currency then
        return (inventory:remove(item.currency, total))
    end

    for _, account in ipairs(Config.ShopAccounts) do
        if (exports.qbx_core:GetMoney(src, account) or 0) >= total then
            return exports.qbx_core:RemoveMoney(src, account, total, ('shop-%s'):format(item.name)), account
        end
    end

    return false
end

---@param src integer
---@param item ShopItem
---@return table
local function itemMetadata(src, item)
    local metadata = lib.table.deepclone(item.metadata or {})
    if not Items[item.name].weapon then return metadata end

    -- ox_inventory's shop rules: registered = the buyer's name, serial = an optional prefix plus a unique part
    if metadata.registered then
        local charinfo = exports.qbx_core:GetPlayer(src).PlayerData.charinfo
        metadata.registered = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    end

    metadata.serial = ('%s%s'):format(metadata.serial or '', lib.string.random('111AAA111AA'))

    return metadata
end

---Buys `count` of the shop item in `shopSlot` into the player's inventory (at `toSlot` when it fits there).
---@param src integer
---@param inventory Inventory
---@param shopSlot unknown
---@param toSlot unknown
---@param count unknown
---@return boolean success
---@return string? reason
function shops.buy(src, inventory, shopSlot, toSlot, count)
    local session = sessions[src]
    if not session then return false, 'stash_closed' end

    if #(GetEntityCoords(GetPlayerPed(src)) - session.coords) > Config.ShopDistance then
        shops.close(src)
        TriggerClientEvent('city_inventory:client:closeOther', src)
        return false, 'stash_closed'
    end

    local shop = session.shop
    shopSlot = type(shopSlot) == 'number' and math.tointeger(shopSlot)
    local item = shopSlot and shop.items[shopSlot]
    count = count == nil and 1 or type(count) == 'number' and math.tointeger(count)
    if not item or not count or count < 1 then return false, 'invalid_slot' end

    -- Weapons don't stack, so they're bought one at a time
    if Items[item.name].weapon then count = 1 end

    local left = stockOf(session.key, shop)
    if left[shopSlot] and left[shopSlot] < count then return false, 'out_of_stock' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'busy' end

    if item.license and not (player.PlayerData.metadata.licences or {})[item.license] then return false, 'no_license' end
    if item.grade and not access.inGroup(src, shop.groups, item.grade) then return false, 'no_access' end

    local metadata = itemMetadata(src, item)
    if not inventory:canFit(item.name, count, metadata) then return false, 'inventory_full' end

    local total = item.price * count
    if item.currency and search.count(inventory.items, item.currency) < total then return false, 'cannot_afford' end
    local paid, account = pay(src, item, total, inventory)
    if not paid then return false, 'cannot_afford' end

    toSlot = type(toSlot) == 'number' and math.tointeger(toSlot)
    local slot = inventory:isSlot(toSlot) and toSlot or nil
    local success = inventory:add(item.name, count, metadata, slot)

    -- The slot dropped on was taken by something else: put it wherever it fits
    if not success and slot then
        success = inventory:add(item.name, count, metadata)
    end

    if not success then
        lib.print.error(('Player %s paid %s for %sx %s but it did not fit; refunding'):format(src, total, count, item.name))

        if item.currency then
            inventory:add(item.currency, total)
        elseif account then
            exports.qbx_core:AddMoney(src, account, total, 'shop-refund')
        end

        return false, 'inventory_full'
    end

    -- city_police registers every weapon bought in a shop by its serial
    if Items[item.name].weapon then
        TriggerEvent('city_inventory:server:boughtWeapon', src, item.name, metadata, shop.label)
    end

    if left[shopSlot] then
        left[shopSlot] = left[shopSlot] - count

        for viewer in pairs(viewers[session.key]) do
            TriggerClientEvent('city_inventory:client:updateOther', viewer, { [shopSlot] = slotsFor(session.key, shop)[shopSlot] })
        end
    end

    return true
end

for shopType, data in pairs(require 'data.shops') do
    shops.register(shopType, data)
end

return shops
