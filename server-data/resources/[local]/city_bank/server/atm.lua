-- ATM and branch cash desk: pick a card from the inventory, type its PIN, then withdraw or deposit cash
-- (BANCO_DESIGN.md 5). Whoever holds a card and knows its PIN can use it, within the limits its owner set.
local access = require 'server.access'
local accounts = require 'server.accounts'
local cards = require 'server.cards'
local money = require 'server.money'
local settings = require 'server.config'

local sessions = {}

local function fail(code, extra)
    local reply = extra or {}
    reply.ok, reply.error = false, code
    return reply
end

---Where the request comes from: an ATM the player stands at, or the branch desk they opened
---@param src integer
---@param mode unknown
---@param coords unknown
---@return boolean
local function placeOk(src, mode, coords)
    if mode == 'teller' then return access.atBranch(src) ~= nil end

    -- ATMs are map props the server can't list, so it checks the player is right next to the reported spot
    if mode ~= 'atm' or type(coords) ~= 'vector3' then return false end

    return access.near(src, coords, settings.atm.maxDistance)
end

---@param src integer
---@return table? session
---@return table? card
local function current(src)
    local session = sessions[src]

    if not session or os.time() - session.at > settings.atm.session then
        sessions[src] = nil
        return
    end

    if not placeOk(src, session.mode, session.coords) then return end

    -- The card must still be in the same slot (not dropped or handed over mid-session)
    local card = cards.fromSlot(src, session.slot)

    if not card or card.card_id ~= session.cardId or card.status ~= 'active' then return end

    session.at = os.time()

    return session, card
end

lib.callback.register('city_bank:atmCards', function(source)
    local src = source

    if access.throttled(src, 'atmCards') then return { ok = false, error = 'busy' } end

    return { ok = true, cards = cards.inInventory(src) }
end)

lib.callback.register('city_bank:atmAuth', function(source, slot, pin, mode, coords)
    local src = source

    if access.throttled(src, 'atmAuth') then return fail('busy') end
    if not placeOk(src, mode, coords) then return fail('far') end

    local card, err = cards.fromSlot(src, slot)

    if not card then return fail(err) end

    local ok, pinError, triesLeft = cards.checkPin(card, pin)

    if not ok then
        if pinError == 'card_locked' then
            exports.city_economy:Flag(src, 'card_pin_locked', 1, { card = card.last4 })
        end

        return fail(pinError, { triesLeft = triesLeft })
    end

    sessions[src] = { slot = access.int(slot), cardId = card.card_id, mode = mode, coords = coords, at = os.time() }

    return { ok = true, last4 = card.last4, holder = card.holder_name }
end)

---The "eye": the balance only shows to the account's owner or members (BANCO_DESIGN.md 5)
lib.callback.register('city_bank:atmPeek', function(source)
    local src = source
    local _, card = current(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not card or not player then return fail('session') end

    local account = exports.city_economy:BankGetAccount(card.account_id)
    local perms = accounts.perms(player, account)

    if not perms then return fail('fingerprint_invalid') end

    return { ok = true, balance = account.balance }
end)

lib.callback.register('city_bank:atmWithdraw', function(source, amount)
    local src = source

    if access.throttled(src, 'atmMove') then return fail('busy') end

    local session, card = current(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not session or not player then return fail('session') end

    local max = session.mode == 'teller' and settings.teller.maxOperation or settings.atm.maxOperation

    amount = access.int(amount)

    if not amount or amount <= 0 then return fail('bad_amount') end
    if amount > max then return fail('atm_max') end

    local limits = cards.limits(card)

    if cards.spentToday(card.card_id, { 'atm' }) + amount > (limits.atmDay or 0) then return fail('card_limit') end

    -- A member of a shared account also has the daily limit the owner gave them
    local holder = exports.qbx_core:GetPlayerByCitizenId(card.holder) or { PlayerData = { citizenid = card.holder } }
    local account = exports.city_economy:BankGetAccount(card.account_id)
    local _, dailyLimit = accounts.perms(holder, account)
    local room = accounts.memberRoom(account, card.holder, dailyLimit)

    if room and amount > room then return fail('member_limit') end

    local _, cash = money.playerAccounts(player.PlayerData.citizenid)
    local reason = session.mode == 'teller' and 'bank-teller-withdraw' or 'bank-atm-withdraw'
    local ok, err = money.move(card.account_id, cash.id, amount, reason, card.holder, { by = player.PlayerData.citizenid, card = card.last4 })

    if not ok then return fail(err == 'insufficient funds' and 'insufficient' or err == 'account frozen' and 'frozen' or 'failed') end

    cards.record(card.card_id, 'atm', amount)

    return { ok = true }
end)

lib.callback.register('city_bank:atmDeposit', function(source, amount)
    local src = source

    if access.throttled(src, 'atmMove') then return fail('busy') end

    local session, card = current(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not session or not player then return fail('session') end

    local max = session.mode == 'teller' and settings.teller.maxOperation or settings.atm.maxOperation

    amount = access.int(amount)

    if not amount or amount <= 0 then return fail('bad_amount') end
    if amount > max then return fail('atm_max') end

    local citizenid = player.PlayerData.citizenid
    local _, cash = money.playerAccounts(citizenid)
    local reason = session.mode == 'teller' and 'bank-teller-deposit' or 'bank-atm-deposit'
    local ok, err = money.move(cash.id, card.account_id, amount, reason, citizenid, { card = card.last4 })

    if not ok then return fail(err == 'insufficient funds' and 'no_cash' or err == 'account frozen' and 'frozen' or 'failed') end

    cards.record(card.card_id, 'deposit', amount)

    -- Big cash deposits go through, but staff hear about them (BANCO_DESIGN.md 5, 13.6)
    local today = cards.spentToday(card.card_id, { 'deposit' })

    if amount >= settings.atm.depositFlagOne or today >= settings.atm.depositFlagDay then
        exports.city_economy:Flag(src, 'large_cash_deposit', 2, { amount = amount, today = today, card = card.last4 })
    end

    return { ok = true }
end)

lib.callback.register('city_bank:atmClose', function(source)
    sessions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
