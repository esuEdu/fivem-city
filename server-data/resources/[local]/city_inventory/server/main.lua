local Inventory = require 'server.inventory'
local players = require 'server.players'
local stashes = require 'server.stashes'
local trades = require 'server.trades'
local drops = require 'server.drops'
local other = require 'server.other'
local storage = require 'server.storage'
local cashflow = require 'server.cashflow'

-- The cash item is the player's cash: every move of it goes through city_economy's ledger (server/cashflow.lua).
-- The modules only get these hooks here, so their unit tests run without the economy.
Inventory.cashHooks = { before = cashflow.beforeTransfer, after = cashflow.afterTransfer }

drops.cash = {
    isCash = cashflow.isCash,
    lost = function(amount, id) cashflow.move('ground', 'sink', amount, { drop = id }) end,
}

trades.cashHooks = {
    isCash = cashflow.isCash,
    toPocket = function(inventory, amount) return cashflow.move('ground', cashflow.side(inventory), amount) end,
    toGround = function(inventory, amount) return cashflow.move(cashflow.side(inventory), 'ground', amount) end,
}

players.cash = {
    item = Config.CashItem,
    isCash = cashflow.isCash,
    expected = function(src) return math.tointeger(exports.qbx_core:GetMoney(src, 'cash')) end,
    mismatch = function(src, have, want)
        if GetResourceState('city_economy') ~= 'started' then return end
        exports.city_economy:Flag(src, 'cash_item_mismatch', 4, { inventory = have, ledger = want })
    end,
}

-- Drops and trade offers only live in memory: cash that was on the ground when this resource stopped is gone
CreateThread(function()
    while GetResourceState('city_economy') ~= 'started' do Wait(500) end

    exports.city_economy:CashResetGround()

    -- Cash can only move once the old ground balance is written off, or a drop made meanwhile would be wiped too
    cashflow.ready = true
end)

---@param src integer
local function loadPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    players.load(src, player.PlayerData.citizenid)
end

MySQL.ready(function()
    storage.init()

    -- Restarting the resource with players online: load everyone already logged in
    for _, playerData in ipairs(exports.qbx_core:GetPlayersData()) do
        loadPlayer(playerData.source)
    end
end)

-- qbx_core sets this when a character has loaded, for whichever inventory resource is running
AddStateBagChangeHandler('loadInventory', nil, function(bagName, _, value)
    if not value then return end

    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    CreateThread(function()
        loadPlayer(src)
    end)
end)

-- Close whatever is open next to the inventory first: a trade gives offered items back before the inventory is saved
AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    other.closeAll(src)
    players.unload(src)
end)

AddEventHandler('playerDropped', function()
    other.closeAll(source)
    players.unload(source)
end)

CreateThread(function()
    while true do
        Wait(Config.AutosaveMinutes * 60000)
        players.saveAll()
        stashes.saveAll()
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    trades.cancelAll()
    players.saveAll(false)
    stashes.saveAll(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    trades.cancelAll()
    players.saveAll(false)
    stashes.saveAll(false)
end)
