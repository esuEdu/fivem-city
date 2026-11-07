-- Photos in the database: the image itself (a small webp as a data URI) with its owner's citizenid
local store = {}

local ready = promise.new()

function store.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_photos` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `data` MEDIUMTEXT NOT NULL,
            `favorite` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

local function wait()
    Citizen.Await(ready)
end

function store.count(citizenid)
    wait()
    return MySQL.scalar.await('SELECT COUNT(*) FROM `phone_photos` WHERE `citizenid` = ?', { citizenid }) or 0
end

function store.add(citizenid, data)
    wait()
    return MySQL.insert.await('INSERT INTO `phone_photos` (`citizenid`, `data`, `created_at`) VALUES (?, ?, ?)', { citizenid, data, os.time() })
end

---The list without the images (the page loads each image when it shows it)
function store.list(citizenid)
    wait()
    local rows = MySQL.query.await('SELECT `id`, `favorite`, `created_at` FROM `phone_photos` WHERE `citizenid` = ? ORDER BY `id` DESC', { citizenid })

    for i = 1, #rows do rows[i].favorite = rows[i].favorite == true or rows[i].favorite == 1 end

    return rows
end

function store.data(citizenid, id)
    wait()
    return MySQL.scalar.await('SELECT `data` FROM `phone_photos` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
end

function store.setFavorite(citizenid, id, favorite)
    wait()
    return MySQL.update.await('UPDATE `phone_photos` SET `favorite` = ? WHERE `id` = ? AND `citizenid` = ?', { favorite and 1 or 0, id, citizenid }) > 0
end

function store.delete(citizenid, id)
    wait()
    return MySQL.update.await('DELETE FROM `phone_photos` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid }) > 0
end

return store
