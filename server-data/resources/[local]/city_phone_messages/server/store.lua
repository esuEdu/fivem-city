-- Chats in the database. Members are phone numbers (a character's number never changes), so messages reach players
-- who are offline and are waiting when they come back.
local store = {}

local ready = promise.new()

function store.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_conversations` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(40) NULL,
            `owner` VARCHAR(20) NULL,
            `is_group` TINYINT(1) NOT NULL DEFAULT 0,
            `last_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_conversation_members` (
            `conversation_id` INT NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            `last_read` INT NOT NULL DEFAULT 0,
            `last_delivered` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`conversation_id`, `number`),
            KEY `number` (`number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_messages` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `conversation_id` INT NOT NULL,
            `sender` VARCHAR(20) NOT NULL,
            `kind` ENUM('text', 'location', 'live', 'system') NOT NULL DEFAULT 'text',
            `body` TEXT NOT NULL,
            `at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `conversation` (`conversation_id`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_message_reactions` (
            `message_id` INT NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            `reaction` VARCHAR(12) NOT NULL,
            PRIMARY KEY (`message_id`, `number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

local function wait()
    Citizen.Await(ready)
end

---Does any character have this number?
function store.numberExists(number)
    wait()
    return MySQL.scalar.await([[
        SELECT 1 FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.phone')) = ? LIMIT 1
    ]], { number }) ~= nil
end

function store.members(conversationId)
    wait()
    return MySQL.query.await('SELECT `number`, `last_read`, `last_delivered` FROM `phone_conversation_members` WHERE `conversation_id` = ?', { conversationId })
end

function store.isMember(conversationId, number)
    wait()
    return MySQL.scalar.await('SELECT 1 FROM `phone_conversation_members` WHERE `conversation_id` = ? AND `number` = ?', { conversationId, number }) ~= nil
end

function store.conversation(id)
    wait()
    return MySQL.single.await('SELECT `id`, `name`, `owner`, `is_group`, `last_at` FROM `phone_conversations` WHERE `id` = ?', { id })
end

---The 1:1 chat between two numbers, if there is one
function store.direct(a, b)
    wait()
    return MySQL.scalar.await([[
        SELECT `c`.`id` FROM `phone_conversations` `c`
        JOIN `phone_conversation_members` `m1` ON `m1`.`conversation_id` = `c`.`id` AND `m1`.`number` = ?
        JOIN `phone_conversation_members` `m2` ON `m2`.`conversation_id` = `c`.`id` AND `m2`.`number` = ?
        WHERE `c`.`is_group` = 0 LIMIT 1
    ]], { a, b })
end

---@param numbers string[]
function store.create(numbers, isGroup, name, owner)
    wait()

    local id = MySQL.insert.await('INSERT INTO `phone_conversations` (`name`, `owner`, `is_group`, `last_at`) VALUES (?, ?, ?, ?)', { name, owner, isGroup and 1 or 0, os.time() })
    local rows = {}

    for i = 1, #numbers do rows[i] = { id, numbers[i] } end
    MySQL.prepare.await('INSERT IGNORE INTO `phone_conversation_members` (`conversation_id`, `number`) VALUES (?, ?)', rows)

    return id
end

function store.addMember(conversationId, number)
    wait()
    local last = MySQL.scalar.await('SELECT COALESCE(MAX(`id`), 0) FROM `phone_messages` WHERE `conversation_id` = ?', { conversationId })
    MySQL.insert.await('INSERT IGNORE INTO `phone_conversation_members` (`conversation_id`, `number`, `last_read`, `last_delivered`) VALUES (?, ?, ?, ?)', { conversationId, number, last, last })
end

function store.removeMember(conversationId, number)
    wait()
    MySQL.update.await('DELETE FROM `phone_conversation_members` WHERE `conversation_id` = ? AND `number` = ?', { conversationId, number })
end

function store.rename(conversationId, name)
    wait()
    MySQL.update.await('UPDATE `phone_conversations` SET `name` = ? WHERE `id` = ?', { name, conversationId })
end

function store.addMessage(conversationId, sender, kind, body)
    wait()
    local now = os.time()
    local id = MySQL.insert.await('INSERT INTO `phone_messages` (`conversation_id`, `sender`, `kind`, `body`, `at`) VALUES (?, ?, ?, ?, ?)', { conversationId, sender, kind, body, now })

    MySQL.update.await('UPDATE `phone_conversations` SET `last_at` = ? WHERE `id` = ?', { now, conversationId })
    -- The sender has read their own message
    MySQL.update.await('UPDATE `phone_conversation_members` SET `last_read` = ?, `last_delivered` = ? WHERE `conversation_id` = ? AND `number` = ?', { id, id, conversationId, sender })

    return { id = id, conversation = conversationId, sender = sender, kind = kind, body = body, at = now, reactions = {} }
end

---A number's chats, newest first, with the last message and how many are unread
function store.list(number)
    wait()
    return MySQL.query.await([[
        SELECT `c`.`id`, `c`.`name`, `c`.`owner`, `c`.`is_group`, `c`.`last_at`,
            (SELECT COUNT(*) FROM `phone_messages` `x` WHERE `x`.`conversation_id` = `c`.`id` AND `x`.`id` > `m`.`last_read` AND `x`.`sender` <> ?) AS `unread`,
            (SELECT `body` FROM `phone_messages` `y` WHERE `y`.`conversation_id` = `c`.`id` ORDER BY `y`.`id` DESC LIMIT 1) AS `last_body`,
            (SELECT `kind` FROM `phone_messages` `z` WHERE `z`.`conversation_id` = `c`.`id` ORDER BY `z`.`id` DESC LIMIT 1) AS `last_kind`
        FROM `phone_conversations` `c`
        JOIN `phone_conversation_members` `m` ON `m`.`conversation_id` = `c`.`id` AND `m`.`number` = ?
        ORDER BY `c`.`last_at` DESC LIMIT ?
    ]], { number, number, Config.MaxConversations })
end

---Messages of a chat, newest page first (before = an id to page back from)
function store.messages(conversationId, before)
    wait()

    local rows = MySQL.query.await([[
        SELECT `id`, `sender`, `kind`, `body`, `at` FROM `phone_messages`
        WHERE `conversation_id` = ? AND `id` < ? ORDER BY `id` DESC LIMIT ?
    ]], { conversationId, before or 2147483647, Config.PageSize })

    if #rows == 0 then return rows end

    local ids, byId = {}, {}
    for i = 1, #rows do
        ids[i] = rows[i].id
        rows[i].reactions = {}
        byId[rows[i].id] = rows[i]
    end

    local reactions = MySQL.query.await(('SELECT `message_id`, `number`, `reaction` FROM `phone_message_reactions` WHERE `message_id` IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
    for i = 1, #reactions do
        local row = reactions[i]
        byId[row.message_id].reactions[row.number] = row.reaction
    end

    return rows
end

function store.message(id)
    wait()
    return MySQL.single.await('SELECT `id`, `conversation_id`, `sender`, `kind`, `body` FROM `phone_messages` WHERE `id` = ?', { id })
end

function store.setReaction(messageId, number, reaction)
    wait()

    if reaction then
        MySQL.insert.await('INSERT INTO `phone_message_reactions` (`message_id`, `number`, `reaction`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `reaction` = VALUES(`reaction`)', { messageId, number, reaction })
    else
        MySQL.update.await('DELETE FROM `phone_message_reactions` WHERE `message_id` = ? AND `number` = ?', { messageId, number })
    end
end

---Marks read (and delivered) up to a message id; never goes back
function store.markRead(conversationId, number, upTo)
    wait()
    MySQL.update.await([[
        UPDATE `phone_conversation_members` SET `last_read` = GREATEST(`last_read`, ?), `last_delivered` = GREATEST(`last_delivered`, ?)
        WHERE `conversation_id` = ? AND `number` = ?
    ]], { upTo, upTo, conversationId, number })
end

---A message reached this number's phone
function store.delivered(conversationId, number, upTo)
    wait()
    MySQL.update.await('UPDATE `phone_conversation_members` SET `last_delivered` = GREATEST(`last_delivered`, ?) WHERE `conversation_id` = ? AND `number` = ?', { upTo, conversationId, number })
end

function store.setOwner(conversationId, number)
    wait()
    MySQL.update.await('UPDATE `phone_conversations` SET `owner` = ? WHERE `id` = ?', { number, conversationId })
end

---Everything up to now reached this number's phone
function store.markDelivered(number)
    wait()
    MySQL.update.await([[
        UPDATE `phone_conversation_members` `m` SET `m`.`last_delivered` = (
            SELECT COALESCE(MAX(`id`), 0) FROM `phone_messages` WHERE `conversation_id` = `m`.`conversation_id`
        ) WHERE `m`.`number` = ?
    ]], { number })
end

return store
