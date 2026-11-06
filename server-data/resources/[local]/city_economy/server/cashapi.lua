-- Exports for city_inventory only: the cash item moving between pockets, the ground and storage.
-- A character's cash account always equals the money item in their inventory; cash outside any pocket sits in
-- CASH_GROUND (drops, trade offers) or CASH_STORED (stashes, trunks, gloveboxes). Moving the item never creates money.
local accounts = require 'server.accounts'
local ledger = require 'server.ledger'
local validation = require 'server.validation'
local settings = require 'server.config'

local CALLER = 'city_inventory'
local REASON = '^cash%-[%w%-]+$'
local PLACES = { ground = 'CASH_GROUND', stored = 'CASH_STORED', sink = 'WORLD_SINK' }

---@return boolean
local function trusted()
    if GetInvokingResource() == CALLER then return true end

    lib.print.warn(('%s used a city_inventory-only cash export, refused'):format(tostring(GetInvokingResource())))
    return false
end

---A side of a cash move: { citizenid = '...' } for a pocket, or 'ground' / 'stored' / 'sink'
---@param side unknown
---@return integer? accountId
---@return string? citizenid
local function resolve(side)
    if type(side) == 'string' then
        local name = PLACES[side]
        return name and accounts.system(name), nil
    end

    if type(side) == 'table' and type(side.citizenid) == 'string' then
        local _, cash = accounts.ensurePlayer(side.citizenid)
        return cash and cash.id, side.citizenid
    end
end

---Updates qbx_core's copy of an online character's cash without touching the item (the inventory already moved it)
---@param citizenid string
---@param balance integer
local function mirrorCash(citizenid, balance)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)

    if player then exports.qbx_core:SyncEconomyMoney(player.PlayerData.source, { cash = balance }, true) end
end

---@param from table | string
---@param to table | string
---@param amount integer
---@param reason string 'cash-...'
---@param meta table?
---@return boolean ok
---@return string? error
local function cashMove(from, to, amount, reason, meta)
    if not trusted() then return false, 'not allowed' end
    if type(reason) ~= 'string' or not reason:find(REASON) then return false, 'bad reason' end
    if from == 'sink' then return false, 'bad side' end

    amount = validation.amount(amount, settings.maxBalance)

    if not amount then return false, 'bad amount' end

    accounts.wait()

    local fromId, fromCid = resolve(from)
    local toId, toCid = resolve(to)

    if not fromId or not toId then return false, 'bad side' end
    if fromId == toId then return true end

    local ok, result, balances = ledger.post({
        { account = fromId, delta = -amount },
        { account = toId, delta = amount },
    }, { reason = reason, source = CALLER, ref = fromCid or toCid, meta = meta, skipMirror = true })

    if not ok then return false, result end

    if fromCid then mirrorCash(fromCid, balances[fromId]) end
    if toCid then mirrorCash(toCid, balances[toId]) end

    return true
end

exports('CashMove', cashMove)

---Drops and trade offers live in memory: when city_inventory starts, whatever cash was on the ground is gone
exports('CashResetGround', function()
    if not trusted() then return false end

    accounts.wait()

    local ground = accounts.system('CASH_GROUND')
    local balance = MySQL.scalar.await('SELECT `balance` FROM `economy_accounts` WHERE `id` = ?', { ground })

    balance = math.tointeger(balance) or 0

    if balance <= 0 then return true end

    return (ledger.post({
        { account = ground, delta = -balance },
        { account = accounts.system('WORLD_SINK'), delta = balance },
    }, { reason = 'cash-ground-reset', source = CALLER }))
end)
