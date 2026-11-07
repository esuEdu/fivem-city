-- The DarkChat tables: aliases, rooms (password hashed), who is in which room, and messages (deleted after
-- Config.MessageHours). The citizenid of a message's writer stays on the server; pages only see the alias.
local store = {}

local ready = promise.new()

function store.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_darkchat_users` (
            `citizenid` VARCHAR(50) NOT NULL,
            `alias` VARCHAR(16) NOT NULL,
            PRIMARY KEY (`citizenid`),
            UNIQUE KEY `alias` (`alias`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_darkchat_rooms` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(24) NOT NULL,
            `password` VARCHAR(100) NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_darkchat_members` (
            `room_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `joined_at` INT NOT NULL,
            PRIMARY KEY (`room_id`, `citizenid`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_darkchat_messages` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `room_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `alias` VARCHAR(16) NOT NULL,
            `text` VARCHAR(300) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `room_id` (`room_id`, `id`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

function store.wait()
    if ready.state == 0 then Citizen.Await(ready) end
end

function store.alias(citizenid)
    store.wait()
    return MySQL.scalar.await('SELECT `alias` FROM `phone_darkchat_users` WHERE `citizenid` = ?', { citizenid })
end

---@return boolean ok, string? reason
function store.setAlias(citizenid, alias)
    store.wait()

    local owner = MySQL.scalar.await('SELECT `citizenid` FROM `phone_darkchat_users` WHERE `alias` = ?', { alias })
    if owner and owner ~= citizenid then return false, 'taken' end

    -- Two people asking for the same alias at once: the unique key refuses the second
    local ok = pcall(MySQL.query.await, 'INSERT INTO `phone_darkchat_users` (`citizenid`, `alias`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `alias` = VALUES(`alias`)', {
        citizenid, alias,
    })

    if not ok then return false, 'taken' end
    return true
end

---The rooms a character is in, with the newest message time (for ordering)
function store.rooms(citizenid)
    store.wait()
    return MySQL.query.await([[
        SELECT r.`id`, r.`name`, (r.`password` IS NOT NULL) AS `locked`,
            (SELECT MAX(m.`created_at`) FROM `phone_darkchat_messages` m WHERE m.`room_id` = r.`id`) AS `lastAt`,
            (SELECT COUNT(*) FROM `phone_darkchat_members` x WHERE x.`room_id` = r.`id`) AS `members`
        FROM `phone_darkchat_rooms` r JOIN `phone_darkchat_members` j ON j.`room_id` = r.`id`
        WHERE j.`citizenid` = ? ORDER BY `lastAt` DESC, r.`name`
    ]], { citizenid }) or {}
end

function store.roomByName(name)
    store.wait()
    return MySQL.single.await('SELECT `id`, `name`, `password` FROM `phone_darkchat_rooms` WHERE `name` = ?', { name })
end

function store.createRoom(name, passwordHash)
    store.wait()
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO `phone_darkchat_rooms` (`name`, `password`, `created_at`) VALUES (?, ?, ?)', {
        name, passwordHash, os.time(),
    })
    return ok and id or nil
end

function store.countRooms(citizenid)
    store.wait()
    return MySQL.scalar.await('SELECT COUNT(*) FROM `phone_darkchat_members` WHERE `citizenid` = ?', { citizenid }) or 0
end

function store.isMember(roomId, citizenid)
    store.wait()
    return MySQL.scalar.await('SELECT 1 FROM `phone_darkchat_members` WHERE `room_id` = ? AND `citizenid` = ?', { roomId, citizenid }) ~= nil
end

function store.join(roomId, citizenid)
    MySQL.insert.await('INSERT IGNORE INTO `phone_darkchat_members` (`room_id`, `citizenid`, `joined_at`) VALUES (?, ?, ?)', { roomId, citizenid, os.time() })
end

---Leaving; a room nobody is in any more is deleted with its messages
function store.leave(roomId, citizenid)
    store.wait()
    local removed = MySQL.update.await('DELETE FROM `phone_darkchat_members` WHERE `room_id` = ? AND `citizenid` = ?', { roomId, citizenid })
    if removed < 1 then return false end

    if not MySQL.scalar.await('SELECT 1 FROM `phone_darkchat_members` WHERE `room_id` = ? LIMIT 1', { roomId }) then
        MySQL.update.await('DELETE FROM `phone_darkchat_messages` WHERE `room_id` = ?', { roomId })
        MySQL.update.await('DELETE FROM `phone_darkchat_rooms` WHERE `id` = ?', { roomId })
    end

    return true
end

function store.members(roomId)
    local rows = MySQL.query.await('SELECT `citizenid` FROM `phone_darkchat_members` WHERE `room_id` = ?', { roomId }) or {}
    local list = {}
    for i = 1, #rows do list[i] = rows[i].citizenid end
    return list
end

function store.messages(roomId, citizenid, before)
    local sql = 'SELECT `id`, `alias`, `text`, `created_at` AS `createdAt`, `citizenid` = ? AS `mine` FROM `phone_darkchat_messages` WHERE `room_id` = ? AND `created_at` > ?'
    local params = { citizenid, roomId, os.time() - Config.MessageHours * 3600 }

    if before then
        sql = sql .. ' AND `id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.PageSize

    local rows = MySQL.query.await(sql .. ' ORDER BY `id` DESC LIMIT ?', params) or {}
    for _, row in ipairs(rows) do row.mine = row.mine == 1 or row.mine == true end

    return rows
end

function store.post(roomId, citizenid, alias, text)
    return MySQL.insert.await('INSERT INTO `phone_darkchat_messages` (`room_id`, `citizenid`, `alias`, `text`, `created_at`) VALUES (?, ?, ?, ?, ?)', {
        roomId, citizenid, alias, text, os.time(),
    })
end

function store.purge()
    store.wait()
    MySQL.update.await('DELETE FROM `phone_darkchat_messages` WHERE `created_at` < ?', { os.time() - Config.MessageHours * 3600 })
end

return store
