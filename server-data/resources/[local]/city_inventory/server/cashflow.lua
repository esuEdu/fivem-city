-- Keeps city_economy's ledger in step with the cash item. A player's `money` items ARE their cash: whenever money
-- leaves or enters a pocket inside the inventory (ground, trade offer, stash, trunk, another player), the same amount
-- moves in the ledger first. If the ledger refuses, the item doesn't move. Nothing here ever creates money.
local Items = require 'shared.items'

local cashflow = {}

-- Set by server/main.lua once the cash left on the ground by the last run has been written off
cashflow.ready = false

local CASH = Config.CashItem:lower()
local ECONOMY = 'city_economy'

---@param name unknown
---@return boolean
function cashflow.isCash(name)
    return type(name) == 'string' and (Items[name] and Items[name].name or name):lower() == CASH
end

---Where money in this inventory counts in the ledger: a character's pocket, the ground (drops, trade offers, lost on
---restart) or storage (stashes, trunks, gloveboxes). Other inventories (dry runs, shops) don't hold cash.
---@param inventory Inventory
---@return table | string | nil
function cashflow.side(inventory)
    if inventory.type == 'player' and type(inventory.owner) == 'string' and inventory.owner ~= 'dry-run' then
        return { citizenid = inventory.owner }
    end

    if inventory.type == 'drop' or inventory.type == 'trade' then return 'ground' end
    if inventory.type == 'stash' then return 'stored' end
end

---@param side table | string | nil
---@return string
local function sideName(side)
    return type(side) == 'table' and 'pocket' or tostring(side)
end

---Moves cash in the ledger. Returns true when nothing needs moving (same place, zero).
---@param from table | string | nil
---@param to table | string | nil
---@param amount integer
---@param meta table?
---@return boolean ok
---@return string? reason
function cashflow.move(from, to, amount, meta)
    if amount <= 0 then return true end
    if not from or not to then return false, 'cash_locked' end
    if type(from) == 'string' and from == to then return true end
    if type(from) == 'table' and type(to) == 'table' and from.citizenid == to.citizenid then return true end

    if not cashflow.ready or GetResourceState(ECONOMY) ~= 'started' then return false, 'cash_locked' end

    local reason = ('cash-%s-to-%s'):format(sideName(from), sideName(to))
    local ok, result, err = pcall(function()
        return exports[ECONOMY]:CashMove(from, to, amount, reason, meta)
    end)

    if not ok or not result then
        lib.print.warn(('Cash move refused (%s, $%d): %s'):format(reason, amount, tostring(ok and err or result)))
        return false, 'cash_locked'
    end

    return true
end

---Count of cash items in an inventory
---@param inventory Inventory
---@return integer
function cashflow.count(inventory)
    local total = 0

    for _, item in pairs(inventory.items) do
        if cashflow.isCash(item.name) then total = total + item.count end
    end

    return total
end

---Inventory.transfer calls this right before it changes any slot. `moving` goes from -> to; `swapped` (the stack that
---was in the target slot, when two stacks trade places) goes to -> from. Returns an undo for when the slots changed
---while the ledger was being written.
---@param from Inventory
---@param to Inventory
---@param moving { name: string, count: integer }
---@param swapped { name: string, count: integer }?
---@return boolean ok
---@return string|function reasonOrUndo
function cashflow.beforeTransfer(from, to, moving, swapped)
    local forward = cashflow.isCash(moving.name) and moving.count or 0
    local backward = swapped and cashflow.isCash(swapped.name) and swapped.count or 0

    if forward == 0 and backward == 0 then return true, function() end end

    local fromSide, toSide = cashflow.side(from), cashflow.side(to)

    -- Mark both pockets busy so the mismatch check in players.sync doesn't "fix" them halfway through
    from.cashBusy, to.cashBusy = true, true

    local ok, reason = cashflow.move(fromSide, toSide, forward)

    if ok and backward > 0 then
        ok, reason = cashflow.move(toSide, fromSide, backward)
        if not ok then cashflow.move(toSide, fromSide, forward) end
    end

    if not ok then
        from.cashBusy, to.cashBusy = nil, nil
        return false, reason
    end

    return true, function()
        cashflow.move(toSide, fromSide, forward)
        cashflow.move(fromSide, toSide, backward)
    end
end

---Called after the transfer finished (or was undone)
---@param from Inventory
---@param to Inventory
function cashflow.afterTransfer(from, to)
    from.cashBusy, to.cashBusy = nil, nil
end

return cashflow
