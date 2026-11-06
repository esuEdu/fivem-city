-- Card machine (BANCO_DESIGN.md 6): the merchant types an amount for a nearby customer, the customer sees it on the
-- machine and pays by inserting a card (PIN) or tapping it (contactless, if enabled). The amount is the one stored here
-- when the merchant created the charge; nothing the customer's client sends can change it.
local access = require 'server.access'
local cards = require 'server.cards'
local credit = require 'server.credit'
local money = require 'server.money'
local rules = require 'server.rules'
local settings = require 'server.config'

local ITEM = 'pos_terminal'

local charges = {}
local byMerchant = {}

local function fail(code, extra)
    local reply = extra or {}
    reply.ok, reply.error = false, code
    return reply
end

---The machine in the merchant's hands, registered to their personal account on first use
---@param src integer
---@param slot integer
---@return table? terminal
local function terminal(src, slot)
    local item = exports.city_inventory:GetSlot(src, slot)
    local player = exports.qbx_core:GetPlayer(src)

    if not item or item.name ~= ITEM or not player then return end

    local metadata = type(item.metadata) == 'table' and item.metadata or {}
    local posId = type(metadata.pos_id) == 'string' and metadata.pos_id or nil
    local row = posId and MySQL.single.await('SELECT * FROM `bank_pos` WHERE `pos_id` = ?', { posId })

    if row then return row end

    local citizenid = player.PlayerData.citizenid
    local personal = money.owned(citizenid, 'personal')

    if not personal then return end

    posId = lib.string.random('............'):upper()

    MySQL.insert.await(
        'INSERT INTO `bank_pos` (`pos_id`, `owner`, `account_id`, `created_at`) VALUES (?, ?, ?, ?)',
        { posId, citizenid, personal.id, os.time() }
    )

    metadata.pos_id = posId
    metadata.description = ('Pays into %s'):format(personal.display)
    exports.city_inventory:SetMetadata(src, slot, metadata)

    return MySQL.single.await('SELECT * FROM `bank_pos` WHERE `pos_id` = ?', { posId })
end

exports.qbx_core:CreateUseableItem(ITEM, function(source, item)
    TriggerClientEvent('city_bank:client:posMerchant', source, item.slot)
end)

lib.callback.register('city_bank:posCharge', function(source, slot, targetId, amount)
    local src = source

    if access.throttled(src, 'posCharge') then return fail('busy') end

    slot = access.int(slot)
    targetId = access.int(targetId)
    amount = access.int(amount)

    if not slot or not targetId or targetId == src then return fail('no_player') end
    if not amount or amount <= 0 or amount > settings.pos.maxCharge then return fail('bad_amount') end
    if byMerchant[src] and charges[byMerchant[src]] then return fail('pos_busy') end

    local target = exports.qbx_core:GetPlayer(targetId)

    if not target then return fail('no_player') end
    if not access.near(src, GetEntityCoords(GetPlayerPed(targetId)), settings.pos.maxDistance) then return fail('far') end

    local machine = terminal(src, slot)

    if not machine then return fail('no_pos') end

    local id = lib.string.random('..........')
    local merchant = exports.qbx_core:GetPlayer(src)

    charges[id] = {
        id = id, merchant = src, customer = targetId, amount = amount, posId = machine.pos_id,
        account = machine.account_id, expires = os.time() + settings.pos.expires,
        merchantName = access.name(merchant),
    }
    byMerchant[src] = id

    TriggerClientEvent('city_bank:client:posRequest', targetId, { id = id, amount = amount, merchant = charges[id].merchantName })

    return { ok = true, id = id }
end)

---@param id string
local function close(id)
    local charge = charges[id]

    if not charge then return end

    charges[id] = nil
    if byMerchant[charge.merchant] == id then byMerchant[charge.merchant] = nil end
end

lib.callback.register('city_bank:posCards', function(source, id)
    local charge = type(id) == 'string' and charges[id]

    if not charge or charge.customer ~= source then return { ok = false, error = 'expired' } end

    return { ok = true, cards = cards.inInventory(source) }
end)

lib.callback.register('city_bank:posDecline', function(source, id)
    local charge = type(id) == 'string' and charges[id]

    if charge and charge.customer == source then
        exports.qbx_core:Notify(charge.merchant, locale('notify_pos_declined'), 'error')
        close(id)
    end

    return true
end)

---Pays a charge. method = 'chip' (PIN) or 'tap' (contactless), mode = 'debit' or 'credit'.
lib.callback.register('city_bank:posPay', function(source, id, slot, method, mode, pin)
    local src = source

    if access.throttled(src, 'posPay') then return fail('busy') end

    local charge = type(id) == 'string' and charges[id]

    if not charge or charge.customer ~= src or charge.expires < os.time() then
        if charge then close(id) end
        return fail('expired')
    end

    if method ~= 'chip' and method ~= 'tap' then return fail('bad_request') end
    if mode ~= 'debit' and mode ~= 'credit' then return fail('bad_request') end
    if not access.near(src, GetEntityCoords(GetPlayerPed(charge.merchant)), settings.pos.maxDistance) then return fail('far') end

    local card, err = cards.fromSlot(src, slot)

    if not card then return fail(err) end
    if card.status ~= 'active' then return fail('card_locked') end

    local amount = charge.amount
    local limits = cards.limits(card)

    if method == 'chip' then
        local ok, pinError, triesLeft = cards.checkPin(card, pin)
        if not ok then return fail(pinError, { triesLeft = triesLeft }) end
    else
        if not cards.contactless(card) then return fail('no_contactless') end
        if amount > (limits.contactlessTx or 0) then return fail('contactless_limit') end
        if cards.spentToday(card.card_id, { 'contactless' }) + amount > (limits.contactlessDay or 0) then return fail('contactless_limit') end
    end

    local fee = rules.pctDebit(amount, mode == 'credit' and settings.pos.mdrCreditPct or settings.pos.mdrDebitPct)
    local entries

    if mode == 'debit' then
        if cards.spentToday(card.card_id, { 'debit' }) + amount > (limits.debitDay or 0) then return fail('card_limit') end

        entries = {
            { account = card.account_id, delta = -amount },
            { account = charge.account, delta = amount - fee },
            { account = money.system('GOV_TREASURY'), delta = fee },
        }
    else
        local blocked = credit.check(card, amount, limits)
        if blocked then return fail(blocked) end

        entries = {
            { account = money.system('BANK_RESERVE'), delta = -amount },
            { account = charge.account, delta = amount - fee },
            { account = money.system('GOV_TREASURY'), delta = fee },
        }
    end

    local ok, postError = money.post(entries, 'bank-pos-' .. mode, card.holder, { pos = charge.posId, card = card.last4 })

    if not ok then return fail(postError == 'insufficient funds' and 'insufficient' or postError == 'account frozen' and 'frozen' or 'failed') end

    if mode == 'credit' then credit.use(card.holder, amount) end

    cards.record(card.card_id, mode, amount)
    if method == 'tap' then cards.record(card.card_id, 'contactless', amount) end

    exports.qbx_core:Notify(charge.merchant, locale('notify_pos_paid', amount), 'success')
    close(id)

    return { ok = true }
end)

-- Test command: charges yourself so one person can see and use the customer screen. The money leaves your card and
-- comes back to your personal account minus the machine fee. Admins on duty only.
lib.addCommand('posdemo', {
    help = locale('command_posdemo'),
    params = { { name = 'amount', type = 'number', help = locale('param_amount'), optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    if source == 0 then return end
    if not exports.qbx_core:IsOptin(source) then
        return exports.qbx_core:Notify(source, locale('not_on_duty'), 'error')
    end

    local player = exports.qbx_core:GetPlayer(source)
    local personal = player and money.owned(player.PlayerData.citizenid, 'personal')
    local amount = math.tointeger(args.amount) or 100

    if not personal or amount <= 0 or amount > settings.pos.maxCharge then
        return exports.qbx_core:Notify(source, locale('error_bad_amount'), 'error')
    end

    if byMerchant[source] then close(byMerchant[source]) end

    local id = lib.string.random('..........')

    charges[id] = {
        id = id, merchant = source, customer = source, amount = amount, posId = 'DEMO',
        account = personal.id, expires = os.time() + settings.pos.expires, merchantName = locale('pos_demo_merchant'),
    }
    byMerchant[source] = id

    access.audit(access.name(player), 'pos_demo', player.PlayerData.citizenid, { amount = amount })
    TriggerClientEvent('city_bank:client:posRequest', source, { id = id, amount = amount, merchant = charges[id].merchantName })
end)

-- Charges nobody answered expire on their own
lib.cron.new('* * * * *', function()
    local now = os.time()

    for id, charge in pairs(charges) do
        if charge.expires < now then close(id) end
    end
end)

AddEventHandler('playerDropped', function()
    for id, charge in pairs(charges) do
        if charge.merchant == source or charge.customer == source then close(id) end
    end
end)

