-- Cards tab: issue (only at a branch), block, unlock, limits, contactless and PIN (BANCO_DESIGN.md 4)
local access = require 'server.access'
local accounts = require 'server.accounts'
local cards = require 'server.cards'
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local function fail(code) return { ok = false, error = code } end

---A card this player may manage: their own, or any card on an account where they manage cards
---@param player table
---@param id unknown database id
---@return table? card
---@return boolean? isHolder
local function manageable(player, id)
    id = access.int(id)

    local card = id and MySQL.single.await('SELECT * FROM `bank_cards` WHERE `id` = ?', { id })

    if not card or card.status == 'replaced' then return end

    local citizenid = player.PlayerData.citizenid

    if card.holder == citizenid then return card, true end

    local perms = accounts.perms(player, exports.city_economy:BankGetAccount(card.account_id))

    if perms and perms.cards then return card, false end
end

access.panel('cards', function(_, player, citizenid)
    local list = accounts.list(player)
    local ids, labels = {}, {}

    for i = 1, #list do
        if list[i].perms.cards then
            ids[#ids + 1] = list[i].id
        end
        labels[list[i].id] = list[i].label
    end

    local marks = {}
    for i = 1, #ids do marks[i] = '?' end

    local values = { citizenid }
    for i = 1, #ids do values[#values + 1] = ids[i] end

    local rows = MySQL.query.await(
        ([[SELECT * FROM `bank_cards` WHERE `status` <> 'replaced' AND (`holder` = ?%s) ORDER BY `id`]]):format(
            #ids > 0 and (' OR `account_id` IN (%s)'):format(table.concat(marks, ', ')) or ''
        ),
        values
    ) or {}

    local tier, score = profile.tier(citizenid)
    local out = {}

    for i = 1, #rows do
        local card = rows[i]

        out[i] = {
            id = card.id, last4 = card.last4, holder = card.holder_name, mine = card.holder == citizenid,
            account = labels[card.account_id] or '-', status = card.status, contactless = cards.contactless(card),
            limits = cards.limits(card), ceilings = cards.ceilings(card),
            pending = card.pending and json.decode(card.pending) or nil, pendingAt = card.pending_at,
        }
    end

    local issuable = {}

    for i = 1, #list do
        if list[i].perms.cards and list[i].type ~= 'job' then
            issuable[#issuable + 1] = { id = list[i].id, label = list[i].label, number = list[i].number }
        end
    end

    return {
        ok = true, cards = out, issuable = issuable, tier = tier.label, score = score,
        fees = { first = settings.cards.firstFee, replace = settings.cards.replaceFee },
    }
end)

access.panel('issueCard', function(src, player, citizenid, accountId, pin)
    accountId = access.int(accountId)

    local account = accountId and exports.city_economy:BankGetAccount(accountId)
    local perms = accounts.perms(player, account)

    if not perms or not perms.cards or account.type == 'job' then return fail('no_permission') end
    if not rules.validPin(pin) then return fail('bad_pin') end
    if not exports.city_inventory:CanCarryItem(src, 'bank_card', 1) then return fail('no_space') end

    local previous = MySQL.scalar.await(
        [[SELECT COUNT(*) FROM `bank_cards` WHERE `holder` = ? AND `account_id` = ? AND `status` <> 'replaced']],
        { citizenid, account.id }
    )
    local replacing = (tonumber(previous) or 0) > 0
    local fee = replacing and settings.cards.replaceFee or settings.cards.firstFee
    local personal = money.owned(citizenid, 'personal')

    if fee > 0 then
        local paid, err = money.move(personal.id, money.system('BANK_RESERVE'), fee, 'bank-card-fee', citizenid)

        if not paid then return fail(err == 'insufficient funds' and 'insufficient' or 'failed') end
    end

    local cardId = cards.create(src, player, account, pin)

    if not cardId then
        if fee > 0 then money.move(money.system('BANK_RESERVE'), personal.id, fee, 'bank-card-refund', citizenid) end
        return fail('no_space')
    end

    -- A new card always replaces the old ones of the same holder on the same account
    if replacing then
        MySQL.update.await(
            [[UPDATE `bank_cards` SET `status` = 'replaced' WHERE `holder` = ? AND `account_id` = ? AND `card_id` <> ? AND `status` <> 'replaced']],
            { citizenid, account.id, cardId }
        )
    end

    return { ok = true, fee = fee }
end)

---Reports a card stolen or lost: blocked for good (a new card is a replacement)
access.panel('blockCard', function(_, player, _, id)
    local card = manageable(player, id)

    if not card then return fail('no_permission') end

    MySQL.update.await([[UPDATE `bank_cards` SET `status` = 'blocked' WHERE `id` = ?]], { card.id })

    return { ok = true }
end)

---Unlocks a card after three wrong PINs. Only its holder, only at a branch.
access.panel('unlockCard', function(_, player, _, id)
    local card, isHolder = manageable(player, id)

    if not card or not isHolder then return fail('no_permission') end
    if card.status ~= 'locked' then return fail('bad_request') end

    MySQL.update.await([[UPDATE `bank_cards` SET `status` = 'active', `pin_tries` = 0 WHERE `id` = ?]], { card.id })

    return { ok = true }
end)

access.panel('cardPin', function(_, player, _, id, pin)
    local card, isHolder = manageable(player, id)

    if not card or not isHolder then return fail('no_permission') end
    if not rules.validPin(pin) then return fail('bad_pin') end

    cards.setPin(card.card_id, pin)

    return { ok = true }
end)

---New limits within the card's ceilings; they take effect after a delay (BANCO_DESIGN.md 4.1)
access.panel('cardLimits', function(_, player, _, id, requested)
    local card = manageable(player, id)

    if not card or card.status ~= 'active' then return fail('no_permission') end
    if type(requested) ~= 'table' then return fail('bad_request') end

    local limits = rules.clampLimits(requested, cards.ceilings(card))

    if not limits then return fail('bad_amount') end

    local at = os.time() + settings.cards.limitDelay

    MySQL.update.await('UPDATE `bank_cards` SET `pending` = ?, `pending_at` = ? WHERE `id` = ?', { json.encode(limits), at, card.id })

    return { ok = true, at = at }
end)

access.panel('cardContactless', function(_, player, _, id, enabled)
    local card = manageable(player, id)

    if not card or card.status ~= 'active' or type(enabled) ~= 'boolean' then return fail('no_permission') end

    MySQL.update.await('UPDATE `bank_cards` SET `contactless` = ? WHERE `id` = ?', { enabled and 1 or 0, card.id })

    return { ok = true }
end)
