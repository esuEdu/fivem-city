-- Using an item. Scripts make items usable with exports.qbx_core:CreateUseableItem; items from the Qbox list that
-- ox_inventory used to handle itself (client.status, armour, parachute) are handled here.
-- Items with client.event never reach the server: the client fires the event, as ox_inventory did.

local Items = require 'shared.items'
local Inventory = require 'server.inventory'

local use = {}

-- ox_inventory status values are on a 0-1,000,000 scale (ESX); Qbox statuses go from 0 to 100
local ESX_STATUS_SCALE = 0.0001

---Item effects that ox_inventory had built in. Effects that need the ped on the client are done in client/use.lua.
---@type table<string, fun(src: integer)>
local builtin = {
    armour = function(src)
        SetPedArmour(GetPlayerPed(src), 100)
    end,

    parachute = function() end,
}

---@param src integer
---@param status table<string, number>
local function applyStatus(src, status)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    for name, amount in pairs(status) do
        if type(amount) == 'number' then
            if amount > 100 or amount < -100 then
                amount = amount * ESX_STATUS_SCALE
            end

            local current = Player(src).state[name] or player.PlayerData.metadata[name] or 0
            exports.qbx_core:SetMetadata(src, name, current + amount)
        end
    end
end

---@param inventory Inventory
---@param slot integer
---@param name string
---@param consume? number
local function consumeFrom(inventory, slot, name, consume)
    consume = Inventory.toCount(consume)
    local current = inventory.items[slot]

    -- A use function may have moved or removed the item itself
    if consume and current and current.name == name then
        inventory:remove(name, math.min(consume, current.count), nil, slot)
    end
end

---@param src integer
---@param inventory Inventory
---@param slot integer
---@return boolean success
---@return string | boolean | nil result failure reason, or whether to close the inventory
function use.run(src, inventory, slot)
    local item = inventory.items[slot]
    local definition = Items[item.name]

    local onUse = exports.qbx_core:CanUseItem(item.name)

    if onUse then
        -- The use function can return false to say the item was not used (and must not be consumed)
        if onUse(src, inventory:slotData(slot)) == false then
            return false, 'not_used'
        end
    elseif definition.status or builtin[item.name] then
        if definition.status then
            applyStatus(src, definition.status)
        end

        if builtin[item.name] then
            builtin[item.name](src)
        end
    else
        return false, 'not_usable'
    end

    consumeFrom(inventory, slot, item.name, definition.consume)

    return true, definition.close
end

return use
