-- Config.CashItem in a player's inventory is their qbx_core cash, so scripts that pay with the ox_inventory money
-- item (ox_fuel) take real cash.

local CASH_ITEM = Config.CashItem:lower()
-- Shown in qbx_core's money logs
local REASON = 'inventory-cash-item'

local cash = {}

---@param inventory Inventory
---@param name unknown
---@return boolean
function cash.is(inventory, name)
    return inventory.type == 'player' and type(name) == 'string' and name:lower() == CASH_ITEM
end

---@param inventory Inventory
---@return integer
function cash.count(inventory)
    return exports.qbx_core:GetMoney(inventory.id, 'cash') or 0
end

---@param count unknown
---@return integer?
local function toAmount(count)
    local amount = math.tointeger(tonumber(count or 1))

    return amount and amount > 0 and amount or nil
end

---@param inventory Inventory
---@param count unknown
---@return boolean, string?
function cash.add(inventory, count)
    local amount = toAmount(count)
    if not amount then return false, 'invalid_count' end

    return exports.qbx_core:AddMoney(inventory.id, 'cash', amount, REASON) and true or false
end

---@param inventory Inventory
---@param count unknown
---@return boolean, string?
function cash.remove(inventory, count)
    local amount = toAmount(count)
    if not amount then return false, 'invalid_count' end
    if cash.count(inventory) < amount then return false, 'not_enough_items' end

    return exports.qbx_core:RemoveMoney(inventory.id, 'cash', amount, REASON) and true or false
end

return cash
