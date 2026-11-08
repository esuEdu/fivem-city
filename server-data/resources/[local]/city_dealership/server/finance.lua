-- Financed cars: one city_bank bill per installment, issued every Config.Finance.everyHours. city_bank owns the bills
-- (paying them, late fees, overdue status); this file only issues them, follows their status and takes the car back
-- when too many are overdue. Bills already overdue stay owed after a repossession.
local quote = require 'server.quote'

local finance = {}

local HOUR = 3600
local TICK = 60000

local ready = promise.new()

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `city_dealership_finance` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `vehicle_id` INT NOT NULL,
        `plate` VARCHAR(8) NOT NULL,
        `model` VARCHAR(50) NOT NULL,
        `price` INT NOT NULL,
        `debt` INT NOT NULL,
        `installment` INT NOT NULL,
        `last_installment` INT NOT NULL,
        `count` TINYINT UNSIGNED NOT NULL,
        `issued` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `prepaid` INT NOT NULL DEFAULT 0,
        `next_at` INT NOT NULL,
        `status` ENUM('active', 'paid', 'repossessed', 'closed') NOT NULL DEFAULT 'active',
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`, `status`),
        KEY `due` (`status`, `next_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `city_dealership_installments` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `finance_id` INT UNSIGNED NOT NULL,
        `bill_id` INT UNSIGNED NOT NULL,
        `number` TINYINT UNSIGNED NOT NULL,
        `amount` INT NOT NULL,
        `paid` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `bill` (`bill_id`),
        KEY `finance` (`finance_id`, `paid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    ready:resolve(true)
end)

---@param citizenid string
---@param message string
---@param kind string?
local function notify(citizenid, message, kind)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then exports.qbx_core:Notify(player.PlayerData.source, message, kind or 'inform') end
end

-- SUM() comes back from MySQL as a decimal
---@param value any
---@return integer
local function toInt(value)
    return math.floor(tonumber(value) or 0)
end

---@param citizenid string
---@return integer
function finance.activeCount(citizenid)
    Citizen.Await(ready)

    return MySQL.scalar.await(
        [[SELECT COUNT(*) FROM `city_dealership_finance` WHERE `citizenid` = ? AND `status` = 'active']],
        { citizenid }
    ) or 0
end

---@param data { citizenid: string, vehicleId: integer, plate: string, model: string, price: integer, plan: table }
---@return integer? id
function finance.create(data)
    Citizen.Await(ready)

    local now = os.time()

    return MySQL.insert.await(
        [[INSERT INTO `city_dealership_finance` (`citizenid`, `vehicle_id`, `plate`, `model`, `price`, `debt`, `installment`,
            `last_installment`, `count`, `next_at`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            data.citizenid, data.vehicleId, data.plate, data.model, data.price, data.plan.debt, data.plan.installment,
            data.plan.last, data.plan.count, now + Config.Finance.everyHours * HOUR, now,
        }
    )
end

---Financings of a character still running, for the "My financing" tab
---@param citizenid string
---@return table[]
function finance.list(citizenid)
    Citizen.Await(ready)

    local rows = MySQL.query.await(
        [[SELECT f.*,
            COALESCE(SUM(CASE WHEN i.`paid` = 1 THEN i.`amount` ELSE 0 END), 0) AS `paid_amount`,
            COALESCE(SUM(CASE WHEN i.`paid` = 0 THEN i.`amount` ELSE 0 END), 0) AS `open_amount`,
            COALESCE(SUM(CASE WHEN i.`paid` = 0 AND b.`status` = 'overdue' THEN 1 ELSE 0 END), 0) AS `overdue`
        FROM `city_dealership_finance` f
        LEFT JOIN `city_dealership_installments` i ON i.`finance_id` = f.`id`
        LEFT JOIN `bank_bills` b ON b.`id` = i.`bill_id`
        WHERE f.`citizenid` = ? AND f.`status` = 'active'
        GROUP BY f.`id` ORDER BY f.`id`]],
        { citizenid }
    ) or {}

    local out = {}

    for i = 1, #rows do
        local row = rows[i]

        out[i] = {
            id = row.id,
            model = row.model,
            plate = row.plate,
            debt = row.debt,
            paid = row.prepaid + toInt(row.paid_amount),
            open = toInt(row.open_amount),
            overdue = toInt(row.overdue),
            count = row.count,
            issued = row.issued,
            installment = row.issued + 1 == row.count and row.last_installment or row.installment,
            nextAt = row.issued < row.count and row.next_at or nil,
            payoff = quote.unissued(row.debt, row.installment, row.count, row.issued),
        }
    end

    return out
end

---@param id integer
---@param citizenid string
---@return table?
function finance.get(id, citizenid)
    Citizen.Await(ready)

    return MySQL.single.await(
        [[SELECT * FROM `city_dealership_finance` WHERE `id` = ? AND `citizenid` = ? AND `status` = 'active']],
        { id, citizenid }
    )
end

---Marks every installment as billed after the rest was paid at once. Only succeeds if nothing changed meanwhile.
---@param row table
---@param amount integer what was paid for it
---@return boolean
function finance.settleUnissued(row, amount)
    return MySQL.update.await(
        [[UPDATE `city_dealership_finance` SET `issued` = `count`, `prepaid` = ? WHERE `id` = ? AND `issued` = ? AND `status` = 'active']],
        { amount, row.id, row.issued }
    ) == 1
end

local function issueDue()
    local rows = MySQL.query.await(
        [[SELECT * FROM `city_dealership_finance` WHERE `status` = 'active' AND `issued` < `count` AND `next_at` <= ? LIMIT 100]],
        { os.time() }
    ) or {}

    for i = 1, #rows do
        local row = rows[i]
        local number = row.issued + 1
        local amount = number == row.count and row.last_installment or row.installment
        local label = ('Car financing %s %d/%d'):format(row.plate, number, row.count)
        local billId = exports.city_bank:IssueBill(
            row.citizenid, amount, label, Config.Finance.dueHours * HOUR, ('dealership:%d:%d'):format(row.id, number)
        )

        if not billId then
            lib.print.warn(('city_dealership: could not bill installment %d of financing %d'):format(number, row.id))
        else
            MySQL.insert.await(
                [[INSERT INTO `city_dealership_installments` (`finance_id`, `bill_id`, `number`, `amount`) VALUES (?, ?, ?, ?)]],
                { row.id, billId, number, amount }
            )
            MySQL.update.await(
                [[UPDATE `city_dealership_finance` SET `issued` = ?, `next_at` = `next_at` + ? WHERE `id` = ?]],
                { number, Config.Finance.everyHours * HOUR, row.id }
            )
        end
    end
end

-- Bills paid (or cancelled by staff) in city_bank count as paid installments; financings with everything billed and
-- paid are done
local function followPayments()
    MySQL.update.await([[UPDATE `city_dealership_installments` i JOIN `bank_bills` b ON b.`id` = i.`bill_id`
        SET i.`paid` = 1 WHERE i.`paid` = 0 AND b.`status` IN ('paid', 'cancelled')]])

    local done = MySQL.query.await([[SELECT f.`id`, f.`citizenid`, f.`plate` FROM `city_dealership_finance` f
        WHERE f.`status` = 'active' AND f.`issued` >= f.`count` AND NOT EXISTS (
            SELECT 1 FROM `city_dealership_installments` i WHERE i.`finance_id` = f.`id` AND i.`paid` = 0)]]) or {}

    for i = 1, #done do
        MySQL.update.await([[UPDATE `city_dealership_finance` SET `status` = 'paid' WHERE `id` = ?]], { done[i].id })
        notify(done[i].citizenid, locale('finance_done', done[i].plate), 'success')
    end
end

---@param plate string
local function deleteFromWorld(plate)
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local text = GetVehicleNumberPlateText(vehicles[i]):match('^%s*(.-)%s*$')
        if text == plate then DeleteEntity(vehicles[i]) end
    end
end

local function repossess()
    local rows = MySQL.query.await([[SELECT f.`id`, f.`citizenid`, f.`vehicle_id`, f.`plate`
        FROM `city_dealership_finance` f
        JOIN `city_dealership_installments` i ON i.`finance_id` = f.`id` AND i.`paid` = 0
        JOIN `bank_bills` b ON b.`id` = i.`bill_id` AND b.`status` = 'overdue'
        WHERE f.`status` = 'active'
        GROUP BY f.`id` HAVING COUNT(*) >= ?]], { Config.Finance.repoAfter }) or {}

    for i = 1, #rows do
        local row = rows[i]
        local owner = MySQL.scalar.await('SELECT `citizenid` FROM `player_vehicles` WHERE `id` = ?', { row.vehicle_id })

        MySQL.update.await(
            [[UPDATE `city_dealership_finance` SET `status` = ? WHERE `id` = ?]],
            { owner and 'repossessed' or 'closed', row.id }
        )

        if owner then
            deleteFromWorld(row.plate)
            exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', row.vehicle_id)
            notify(row.citizenid, locale('finance_repossessed', row.plate), 'error')
            lib.print.info(('city_dealership: repossessed %s (financing %d, %s)'):format(row.plate, row.id, row.citizenid))
        end
    end
end

CreateThread(function()
    Citizen.Await(ready)

    while true do
        if GetResourceState('city_bank') == 'started' then
            local ok, err = pcall(function()
                followPayments()
                issueDue()
                repossess()
            end)

            if not ok then lib.print.error(('city_dealership: financing tick failed: %s'):format(err)) end
        end

        Wait(TICK)
    end
end)

---What is still owed on a car's financing (billed or not), 0 when it isn't financed. qbx_vehiclesales checks it.
---@param vehicleId integer
---@return integer
exports('FinanceBalance', function(vehicleId)
    Citizen.Await(ready)

    local balance = MySQL.scalar.await([[SELECT f.`debt` - f.`prepaid` - COALESCE((SELECT SUM(i.`amount`) FROM `city_dealership_installments` i
        WHERE i.`finance_id` = f.`id` AND i.`paid` = 1), 0)
        FROM `city_dealership_finance` f WHERE f.`vehicle_id` = ? AND f.`status` = 'active' LIMIT 1]], { vehicleId })

    return toInt(balance)
end)

---@param vehicleId integer
---@return boolean
exports('IsFinanced', function(vehicleId)
    Citizen.Await(ready)

    return (MySQL.scalar.await(
        [[SELECT COUNT(*) FROM `city_dealership_finance` WHERE `vehicle_id` = ? AND `status` = 'active']],
        { vehicleId }
    ) or 0) > 0
end)

return finance
