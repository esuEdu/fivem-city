-- The Vault tab: the faction's money (every member sees and deposits, the leader withdraws) and a read-only list
-- of what is in the vault stash. Items are only moved at the stash itself, never from the app.
local orgs = require 'server.orgs'
local core = require 'server.app.main'

---The stash contents grouped by item, for the page's read-only list.
---@param gang string
---@return table[] items
---@return integer weight
---@return integer maxWeight
local function vaultItems(gang)
    local inventory = exports.city_inventory:GetInventory(('org:%s'):format(gang))
    if not inventory then return {}, 0, 0 end

    local byName, list = {}, {}

    for _, item in pairs(inventory.items) do
        local entry = byName[item.name]

        if entry then
            entry.count = entry.count + item.count
        else
            local definition = exports.city_inventory:Items(item.name)

            entry = {
                name = item.name,
                label = definition and definition.label or item.name,
                image = definition and definition.client and definition.client.image or ('%s.png'):format(item.name:lower()),
                count = item.count,
            }
            byName[item.name] = entry
            list[#list + 1] = entry
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list, inventory.weight, inventory.maxWeight
end

core.register('vault', function(_, _, faction)
    local items, weight, maxWeight = vaultItems(faction.gang)

    return true, {
        balance = exports.city_bank:OrgBalance(faction.gang, faction.label) or 0,
        items = items,
        weight = weight,
        maxWeight = maxWeight,
    }
end)

---@param value unknown
---@return integer?
local function toAmount(value)
    value = math.tointeger(tonumber(value))

    return value and value > 0 and value or nil
end

core.register('deposit', function(src, player, faction, data)
    local amount = toAmount(data.amount)
    if not amount then return false, 'invalid_amount' end

    local ok, err = exports.city_bank:OrgDeposit(src, faction.gang, amount)
    if not ok then return false, err end

    orgs.log(faction.gang, player.PlayerData.citizenid, 'money_in', ('$%d'):format(amount))
    orgs.refresh(faction.gang, 'data')

    return true
end)

core.register('withdraw', function(src, player, faction, data)
    local amount = toAmount(data.amount)
    if not amount then return false, 'invalid_amount' end

    local ok, err = exports.city_bank:OrgWithdraw(src, faction.gang, amount)
    if not ok then return false, err end

    orgs.log(faction.gang, player.PlayerData.citizenid, 'money_out', ('$%d'):format(amount))
    orgs.refresh(faction.gang, 'data')

    return true
end, { boss = true })
