-- The second panel: a stash or shop the server let the player open. The page shows it; the server sends every change.

local Items = require 'shared.items'

local other = {}

---@class OtherHooks
---@field toNui fun(slot: integer, item?: InventoryItem): table
---@field open fun(): boolean opens the inventory, false when the player can't right now
---@field notifyFailure fun(reason?: string)

---@type OtherHooks
local hooks

---@type string? id of the open stash or shop
local current

---@param value unknown
---@return integer?
local function toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---@param hookFns OtherHooks
function other.init(hookFns)
    hooks = hookFns
end

---@param id string
function other.openStash(id)
    if type(id) ~= 'string' then return end

    local success, reason = lib.callback.await('city_inventory:openStash', false, id)
    if not success then hooks.notifyFailure(reason) end
end

---@param shopType string
---@param id? integer which of the shop's locations
function other.openShop(shopType, id)
    if type(shopType) ~= 'string' then return end

    local success, reason = lib.callback.await('city_inventory:openShop', false, shopType, id)
    if not success then hooks.notifyFailure(reason) end
end

---Closes the panel; the server forgets the player has it open.
function other.close()
    if not current then return end

    current = nil
    SendNUIMessage({ action = 'clearOther' })
    TriggerServerEvent('city_inventory:server:closeOther')
end

---@param slots table<integer, InventoryItem | false>
---@return table[]
local function toEntries(slots)
    local entries = {}

    for slot, item in pairs(slots) do
        local entry = hooks.toNui(slot, item or nil)

        -- Shop items: what one costs, in money or in another item (black money), and how many are left
        if item and item.price then
            entry.item.price = item.price
            entry.item.currency = item.currency and Items[item.currency].label or false
            entry.item.stock = item.stock
        end

        entries[#entries + 1] = entry
    end

    return entries
end

RegisterNetEvent('city_inventory:client:openOther', function(data)
    current = data.id

    SendNUIMessage({
        action = 'setOther',
        kind = data.kind or 'stash',
        label = data.label,
        slots = data.slots,
        maxWeight = data.maxWeight,
        weight = data.weight,
        items = toEntries(data.items),
    })

    if not hooks.open() then other.close() end
end)

RegisterNetEvent('city_inventory:client:updateOther', function(changes, weight)
    if not current then return end

    SendNUIMessage({ action = 'updateOther', changes = toEntries(changes), weight = weight })
end)

-- The server closed it: the player walked away or lost the job
RegisterNetEvent('city_inventory:client:closeOther', function()
    if not current then return end

    current = nil
    SendNUIMessage({ action = 'clearOther' })
    hooks.notifyFailure('stash_closed')
end)

RegisterNUICallback('transfer', function(data, cb)
    cb(1)

    local fromSide, toSide = data.fromInv, data.toInv
    if (fromSide ~= 'player' and fromSide ~= 'other') or (toSide ~= 'player' and toSide ~= 'other') then return end

    local success, reason = lib.callback.await('city_inventory:transfer', false, fromSide, toInteger(data.from), toSide, toInteger(data.to), toInteger(data.count))
    if not success then hooks.notifyFailure(reason) end
end)

return other
