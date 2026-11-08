-- The catalogue and buying: paid in full (cash or bank) or financed (down payment now, installments as bank bills).
-- Bought cars are registered parked at Config.Garage.
local catalog = require 'server.catalog'
local finance = require 'server.finance'
local quote = require 'server.quote'

-- qbx_vehicles is server_only, so it can't be in the manifest's dependencies (clients would refuse to start us)
assert(lib.checkDependency('qbx_vehicles', '1.3.1', true))

local ACCOUNTS = { cash = true, bank = true }
local busy = {}

lib.callback.register('city_dealership:catalog', function(source)
    if not exports.qbx_core:GetPlayer(source) then return end

    return catalog.list()
end)

lib.callback.register('city_dealership:finances', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    return finance.list(player.PlayerData.citizenid)
end)

---@param src integer
---@param citizenid string
---@param entry table
---@param account 'cash'|'bank'
---@param plan table? financing plan, nil when paid in full
---@return string? plate, string? error
local function buy(src, citizenid, entry, account, plan)
    local amount = plan and plan.down or entry.price

    if plan and finance.activeCount(citizenid) >= Config.Finance.maxActive then return nil, 'too_many_financed' end
    if exports.qbx_core:GetMoney(src, account) < amount then return nil, 'no_money' end
    if not exports.qbx_core:RemoveMoney(src, account, amount, 'dealership-buy') then return nil, 'no_money' end

    local function refund()
        exports.qbx_core:AddMoney(src, account, amount, 'dealership-refund')
    end

    local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({ model = entry.model, citizenid = citizenid, garage = Config.Garage })
    local playerVehicle = vehicleId and exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    local plate = playerVehicle and playerVehicle.props and playerVehicle.props.plate

    if not plate then
        if vehicleId then exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', vehicleId) end
        refund()
        return nil, 'failed'
    end

    if plan and not finance.create({
        citizenid = citizenid, vehicleId = vehicleId, plate = plate, model = entry.model, price = entry.price, plan = plan,
    }) then
        exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', vehicleId)
        refund()
        return nil, 'failed'
    end

    lib.print.info(('city_dealership: %s bought %s (%s) for %d, %s'):format(
        citizenid, entry.model, plate, entry.price, plan and ('financed, %d down'):format(plan.down) or account))

    return plate
end

---@param data { model: string, account: string, financed: boolean?, downPct: integer?, count: integer? }
lib.callback.register('city_dealership:buy', function(source, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or type(data) ~= 'table' then return nil, 'failed' end

    local entry = catalog.get(data.model)
    if not entry or not ACCOUNTS[data.account] then return nil, 'failed' end

    if not catalog.atComputer(src) then
        lib.print.warn(('city_dealership: %s tried to buy %s away from a computer'):format(src, entry.model))
        return nil, 'failed'
    end

    local plan

    if data.financed == true then
        plan = quote.plan(entry.price, math.tointeger(data.downPct), math.tointeger(data.count), Config.Finance)
        if not plan then return nil, 'failed' end
    end

    if busy[src] then return nil, 'busy' end
    busy[src] = true

    local ok, plate, err = pcall(buy, src, player.PlayerData.citizenid, entry, data.account, plan)
    busy[src] = nil

    if not ok then
        lib.print.error(plate)
        return nil, 'failed'
    end

    return plate, err
end)

---Pays off what isn't billed yet in one go. Bills already issued are paid in the bank as usual.
lib.callback.register('city_dealership:payOff', function(source, id)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    id = math.tointeger(id)
    if not player or not id then return false, 'failed' end
    if not catalog.atComputer(src) then return false, 'failed' end
    if busy[src] then return false, 'busy' end

    local row = finance.get(id, player.PlayerData.citizenid)
    if not row then return false, 'failed' end

    local amount = quote.unissued(row.debt, row.installment, row.count, row.issued)
    if amount <= 0 then return false, 'nothing_to_pay' end

    busy[src] = true

    local ok, err = pcall(function()
        if exports.qbx_core:GetMoney(src, 'bank') < amount then return 'no_money' end
        if not exports.qbx_core:RemoveMoney(src, 'bank', amount, 'dealership-payoff') then return 'no_money' end

        if not finance.settleUnissued(row, amount) then
            exports.qbx_core:AddMoney(src, 'bank', amount, 'dealership-refund')
            return 'failed'
        end
    end)

    busy[src] = nil

    if not ok then
        lib.print.error(err)
        return false, 'failed'
    end

    if err then return false, err end

    return true
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)
