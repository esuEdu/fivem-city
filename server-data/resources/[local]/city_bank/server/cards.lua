-- Bank cards: the item only carries a random card_id; PIN, limits and status live here (BANCO_DESIGN.md 4)
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local cards = {}

local ITEM = 'bank_card'
local KIND = { debit = true, credit = true, atm = true, contactless = true, deposit = true }

---@param cardId string
---@return table?
function cards.get(cardId)
    if type(cardId) ~= 'string' or #cardId ~= 16 then return end

    return MySQL.single.await('SELECT * FROM `bank_cards` WHERE `card_id` = ?', { cardId })
end

---The ceilings of a card: what a banker set, or else the holder's current tier
---@param card table
---@return table<string, integer>
function cards.ceilings(card)
    local custom = card.ceilings and json.decode(card.ceilings)

    if type(custom) == 'table' then return custom end

    return profile.tierCeilings((profile.tier(card.holder)))
end

---The limits in force now; a pending change takes effect once its delay has passed
---@param card table
---@return table<string, integer>
function cards.limits(card)
    if card.pending and card.pending_at > 0 and card.pending_at <= os.time() then
        MySQL.update.await(
            'UPDATE `bank_cards` SET `limits` = `pending`, `pending` = NULL, `pending_at` = 0 WHERE `id` = ?',
            { card.id }
        )
        card.limits, card.pending, card.pending_at = card.pending, nil, 0
    end

    local limits = json.decode(card.limits) or {}
    local ceilings = cards.ceilings(card)

    -- A tier drop lowers the ceiling: the active limit never stays above it
    for key, ceiling in pairs(ceilings) do
        limits[key] = math.min(math.tointeger(limits[key]) or ceiling, ceiling)
    end

    return limits
end

---Spent with this card in the last 24 hours, for the given kinds
---@param cardId string
---@param kinds string[]
---@return integer
function cards.spentToday(cardId, kinds)
    local marks = {}

    for i = 1, #kinds do marks[i] = '?' end

    local values = { cardId, os.time() - 86400 }

    for i = 1, #kinds do values[#values + 1] = kinds[i] end

    local total = MySQL.scalar.await(
        ('SELECT CAST(COALESCE(SUM(`amount`), 0) AS SIGNED) FROM `bank_card_tx` WHERE `card_id` = ? AND `created_at` >= ? AND `kind` IN (%s)'):format(table.concat(marks, ', ')),
        values
    )

    return math.tointeger(total) or 0
end

---@param cardId string
---@param kind string
---@param amount integer
function cards.record(cardId, kind, amount)
    if not KIND[kind] then return end

    MySQL.insert.await(
        'INSERT INTO `bank_card_tx` (`card_id`, `kind`, `amount`, `created_at`) VALUES (?, ?, ?, ?)',
        { cardId, kind, amount, os.time() }
    )
end

---Checks the PIN. Wrong tries are counted on the card, so changing ATM or character doesn't reset them.
---@param card table
---@param pin unknown
---@return boolean ok
---@return string? error 'wrong_pin' | 'card_locked'
---@return integer? triesLeft
function cards.checkPin(card, pin)
    if card.status == 'locked' then return false, 'card_locked' end

    local matches = rules.validPin(pin) and MySQL.scalar.await(
        'SELECT SHA2(CONCAT(`pin_salt`, ?), 256) = `pin_hash` FROM `bank_cards` WHERE `id` = ?',
        { pin, card.id }
    )

    if matches == 1 or matches == true then
        if card.pin_tries > 0 then MySQL.update.await('UPDATE `bank_cards` SET `pin_tries` = 0 WHERE `id` = ?', { card.id }) end
        return true
    end

    local tries = card.pin_tries + 1
    local locked = tries >= settings.cards.pinAttempts

    MySQL.update.await(
        'UPDATE `bank_cards` SET `pin_tries` = ?, `status` = ? WHERE `id` = ?',
        { tries, locked and 'locked' or card.status, card.id }
    )

    if locked then return false, 'card_locked' end

    return false, 'wrong_pin', settings.cards.pinAttempts - tries
end

---@param cardId string
---@param pin string
function cards.setPin(cardId, pin)
    local salt = lib.string.random('................')

    MySQL.update.await(
        'UPDATE `bank_cards` SET `pin_salt` = ?, `pin_hash` = SHA2(CONCAT(?, ?), 256), `pin_tries` = 0 WHERE `card_id` = ?',
        { salt, salt, pin, cardId }
    )
end

---Creates the card row and puts the item in the player's inventory
---@param src integer
---@param holder table player
---@param account table
---@param pin string
---@return string? cardId
function cards.create(src, holder, account, pin)
    local info = holder.PlayerData.charinfo
    local name = ('%s %s'):format(info.firstname, info.lastname)
    local cardId = lib.string.random('................'):upper()
    local last4 = ('%04d'):format(math.random(0, 9999))
    local salt = lib.string.random('................')
    local tier = profile.tier(holder.PlayerData.citizenid)
    local limits = profile.tierCeilings(tier)

    MySQL.insert.await(
        [[INSERT INTO `bank_cards` (`card_id`, `account_id`, `holder`, `holder_name`, `last4`, `pin_hash`, `pin_salt`, `limits`, `created_at`)
          VALUES (?, ?, ?, ?, ?, SHA2(CONCAT(?, ?), 256), ?, ?, ?)]],
        { cardId, account.id, holder.PlayerData.citizenid, name, last4, salt, pin, salt, json.encode(limits), os.time() }
    )

    local added = exports.city_inventory:AddItem(src, ITEM, 1, {
        card_id = cardId,
        label = ('%s Card •••• %s'):format(tier.label, last4),
        description = ('%s · %s'):format(name, account.label),
        last4 = last4,
    })

    if not added then
        MySQL.update.await('DELETE FROM `bank_cards` WHERE `card_id` = ?', { cardId })
        return nil
    end

    return cardId
end

---Bank cards in a player's inventory, as the ATM and card machine list them
---@param src integer
---@return { slot: integer, cardId: string, last4: string, label: string }[]
function cards.inInventory(src)
    local slots = exports.city_inventory:GetSlotsWithItem(src, ITEM) or {}
    local list = {}

    for i = 1, #slots do
        local metadata = slots[i].metadata or {}

        if type(metadata.card_id) == 'string' then
            list[#list + 1] = {
                slot = slots[i].slot,
                last4 = tostring(metadata.last4 or '????'),
                label = tostring(metadata.label or 'Bank Card'),
            }
        end
    end

    return list
end

---The card in a given inventory slot, checked against the database. The player must really hold it.
---@param src integer
---@param slot unknown
---@return table? card
---@return string? error
function cards.fromSlot(src, slot)
    slot = type(slot) == 'number' and math.tointeger(slot)

    local item = slot and exports.city_inventory:GetSlot(src, slot)

    if not item or item.name ~= ITEM or type(item.metadata) ~= 'table' then return nil, 'no_card' end

    local card = cards.get(item.metadata.card_id)

    if not card then return nil, 'no_card' end
    if card.status == 'blocked' or card.status == 'replaced' then return nil, 'card_blocked' end

    return card
end

return cards
