-- Everything that runs on a clock (real time, server side): due bills, card cycles, loan installments,
-- scheduled transfers, and once a day the savings yield and overdue penalties.
local bills = require 'server.bills'
local credit = require 'server.credit'
local loans = require 'server.loans'
local money = require 'server.money'
local schema = require 'server.schema'
local settings = require 'server.config'
local transfers = require 'server.transfers'

local DAY = 86400

---@param name string
---@return integer
local function lastRun(name)
    return math.tointeger(MySQL.scalar.await('SELECT `value` FROM `bank_state` WHERE `name` = ?', { name })) or 0
end

local function markRun(name, at)
    MySQL.update.await(
        'INSERT INTO `bank_state` (`name`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { name, at }
    )
end

---Savings pay a % of their average balance over the last day, with a daily cap (BANCO_DESIGN.md 3.1)
local function paySavings()
    local rows = MySQL.query.await([[SELECT `id`, `owner` FROM `economy_accounts` WHERE `type` = 'savings' AND `frozen` IS NULL]]) or {}
    local reserve = money.system('BANK_RESERVE')

    for i = 1, #rows do
        local avg = exports.city_economy:BankAverageBalance(rows[i].id, DAY)
        local yield = math.min(math.floor(avg * settings.savings.ratePct / 100), settings.savings.maxPerDay)

        if yield > 0 then money.move(reserve, rows[i].id, yield, 'bank-savings-yield', rows[i].owner) end
    end
end

local function daily()
    local now = os.time()

    if now - lastRun('daily') < DAY then return end

    markRun('daily', now)
    if Config.Features.savings then paySavings() end
    bills.daily()
end

local function tick()
    local createBill = function(data) return bills.create(data) end

    bills.processDue(credit.carry)
    credit.closeCycles(createBill)
    if Config.Features.loans then loans.runDue() end
    if Config.Features.scheduled then transfers.runDue() end
    daily()
end

-- /bankwarp (server/devtools.lua) runs a tick right away after moving a character's dates back.
-- Local event only: clients can't trigger it.
AddEventHandler('city_bank:server:runScheduler', function()
    local ok, err = pcall(tick)

    if not ok then lib.print.error(('Bank scheduler failed: %s'):format(err)) end
end)

CreateThread(function()
    schema.wait()

    while true do
        local ok, err = pcall(tick)

        if not ok then lib.print.error(('Bank scheduler failed: %s'):format(err)) end

        Wait(60000)
    end
end)
