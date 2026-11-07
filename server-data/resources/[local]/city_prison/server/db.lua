-- The prison's tables. One row per character serving or owing time; the log keeps what happened.

local db = {}

function db.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_prison_inmates` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `status` VARCHAR(10) NOT NULL DEFAULT 'serving',
            `months` INT NOT NULL DEFAULT 0,
            `original` INT NOT NULL DEFAULT 0,
            `reduced` INT NOT NULL DEFAULT 0,
            `owed` INT NOT NULL DEFAULT 0,
            `officer` VARCHAR(100) NULL,
            `since` INT NOT NULL,
            PRIMARY KEY (`citizenid`)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_prison_log` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `action` VARCHAR(20) NOT NULL,
            `months` INT NOT NULL DEFAULT 0,
            `actor` VARCHAR(100) NULL,
            `at` INT NOT NULL,
            PRIMARY KEY (`id`),
            INDEX `citizenid` (`citizenid`)
        )
    ]])
end

---@return table<string, table> rows by citizenid
function db.loadAll()
    local byCid = {}

    for _, row in ipairs(MySQL.query.await('SELECT * FROM city_prison_inmates') or {}) do
        byCid[row.citizenid] = row
    end

    return byCid
end

---@param row table
function db.save(row)
    MySQL.prepare.await([[
        INSERT INTO city_prison_inmates (citizenid, name, status, months, original, reduced, owed, officer, since)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), status = VALUES(status), months = VALUES(months),
            original = VALUES(original), reduced = VALUES(reduced), owed = VALUES(owed), officer = VALUES(officer),
            since = VALUES(since)
    ]], { row.citizenid, row.name, row.status, row.months, row.original, row.reduced, row.owed, row.officer, row.since })
end

---Writes the months of many rows at once (the minute tick)
---@param rows table[]
function db.saveMonths(rows)
    if #rows == 0 then return end

    local params = {}
    for i, row in ipairs(rows) do params[i] = { row.months, row.citizenid } end

    MySQL.prepare('UPDATE city_prison_inmates SET months = ? WHERE citizenid = ?', params)
end

function db.delete(citizenid)
    MySQL.update.await('DELETE FROM city_prison_inmates WHERE citizenid = ?', { citizenid })
end

function db.log(citizenid, name, action, months, actor)
    MySQL.insert('INSERT INTO city_prison_log (citizenid, name, action, months, actor, at) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, name, action, months or 0, actor, os.time(),
    })
end

function db.history(limit)
    return MySQL.query.await('SELECT * FROM city_prison_log ORDER BY id DESC LIMIT ?', { limit }) or {}
end

return db
