-- Contacts, recent calls and blocked numbers in the database, always keyed by the owner's citizenid.
local store = {}

local ready = promise.new()

function store.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_contacts` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(40) NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            `favorite` TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_recents` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `number` VARCHAR(20) NOT NULL DEFAULT '',
            `direction` ENUM('in', 'out', 'missed') NOT NULL,
            `duration` INT NOT NULL DEFAULT 0,
            `at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_blocked` (
            `citizenid` VARCHAR(50) NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            PRIMARY KEY (`citizenid`, `number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

local function wait()
    Citizen.Await(ready)
end

---@param citizenid string
function store.contacts(citizenid)
    wait()
    local rows = MySQL.query.await('SELECT `id`, `name`, `number`, `favorite` FROM `phone_contacts` WHERE `citizenid` = ? ORDER BY `name`', { citizenid })

    -- TINYINT(1) comes back as a boolean or a number depending on the driver settings
    for i = 1, #rows do rows[i].favorite = rows[i].favorite == true or rows[i].favorite == 1 end

    return rows
end

function store.countContacts(citizenid)
    wait()
    return MySQL.scalar.await('SELECT COUNT(*) FROM `phone_contacts` WHERE `citizenid` = ?', { citizenid }) or 0
end

function store.addContact(citizenid, name, number, favorite)
    wait()
    return MySQL.insert.await('INSERT INTO `phone_contacts` (`citizenid`, `name`, `number`, `favorite`) VALUES (?, ?, ?, ?)', { citizenid, name, number, favorite and 1 or 0 })
end

function store.updateContact(citizenid, id, name, number, favorite)
    wait()
    return MySQL.update.await('UPDATE `phone_contacts` SET `name` = ?, `number` = ?, `favorite` = ? WHERE `id` = ? AND `citizenid` = ?', { name, number, favorite and 1 or 0, id, citizenid }) > 0
end

function store.deleteContact(citizenid, id)
    wait()
    return MySQL.update.await('DELETE FROM `phone_contacts` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid }) > 0
end

function store.recents(citizenid)
    wait()
    return MySQL.query.await('SELECT `id`, `number`, `direction`, `duration`, `at` FROM `phone_recents` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?', { citizenid, Config.RecentsKept })
end

---@param number string '' when the number was hidden
function store.addRecent(citizenid, number, direction, duration)
    wait()
    MySQL.insert.await('INSERT INTO `phone_recents` (`citizenid`, `number`, `direction`, `duration`, `at`) VALUES (?, ?, ?, ?, ?)', { citizenid, number, direction, duration, os.time() })

    -- Keep only the newest ones
    MySQL.update.await([[
        DELETE FROM `phone_recents` WHERE `citizenid` = ? AND `id` < (
            SELECT `id` FROM (SELECT `id` FROM `phone_recents` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 1 OFFSET ?) AS `keep`
        )
    ]], { citizenid, citizenid, Config.RecentsKept - 1 })
end

function store.clearRecents(citizenid)
    wait()
    MySQL.update.await('DELETE FROM `phone_recents` WHERE `citizenid` = ?', { citizenid })
end

function store.blocked(citizenid)
    wait()
    local rows = MySQL.query.await('SELECT `number` FROM `phone_blocked` WHERE `citizenid` = ? ORDER BY `number`', { citizenid })
    local list = {}

    for i = 1, #rows do list[i] = rows[i].number end

    return list
end

function store.isBlocked(citizenid, number)
    wait()
    return MySQL.scalar.await('SELECT 1 FROM `phone_blocked` WHERE `citizenid` = ? AND `number` = ?', { citizenid, number }) ~= nil
end

function store.setBlocked(citizenid, number, blocked)
    wait()

    if not blocked then
        MySQL.update.await('DELETE FROM `phone_blocked` WHERE `citizenid` = ? AND `number` = ?', { citizenid, number })
        return true
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `phone_blocked` WHERE `citizenid` = ?', { citizenid }) or 0
    if count >= Config.MaxBlocked then return false end

    MySQL.insert.await('INSERT IGNORE INTO `phone_blocked` (`citizenid`, `number`) VALUES (?, ?)', { citizenid, number })
    return true
end

return store
