-- Orders that finish later: smelting (public smelter and home furnaces), gem cutting and jewellery. Each is a row
-- in city_mining_orders with the time it's ready; nothing runs while it waits. One open order per character per place.
local orders = {}

function orders.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_mining_orders` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `place` VARCHAR(40) NOT NULL,
            `recipe` VARCHAR(40) NOT NULL,
            `count` INT NOT NULL,
            `data` LONGTEXT NULL,
            `ready_at` INT NOT NULL,
            `created_at` INT NOT NULL,
            INDEX `citizen_place` (`citizenid`, `place`)
        )
    ]])
end

---@param row table?
---@return table?
local function decode(row)
    if not row then return end

    row.data = row.data and json.decode(row.data) or {}

    return row
end

---@param citizenid string
---@param place string
---@return table? order
function orders.get(citizenid, place)
    return decode(MySQL.single.await('SELECT `id`, `recipe`, `count`, `data`, `ready_at`, `created_at` FROM `city_mining_orders` WHERE `citizenid` = ? AND `place` = ? LIMIT 1', { citizenid, place }))
end

---The order at a place no matter whose (home furnaces: one per furnace).
---@param place string
---@return table? order with citizenid
function orders.at(place)
    return decode(MySQL.single.await('SELECT `id`, `citizenid`, `recipe`, `count`, `data`, `ready_at`, `created_at` FROM `city_mining_orders` WHERE `place` = ? LIMIT 1', { place }))
end

---@param citizenid string
---@param place string
---@param recipe string
---@param count integer
---@param seconds number
---@param data table?
---@return integer? id
function orders.create(citizenid, place, recipe, count, seconds, data)
    local now = os.time()

    return MySQL.insert.await('INSERT INTO `city_mining_orders` (`citizenid`, `place`, `recipe`, `count`, `data`, `ready_at`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenid, place, recipe, count, json.encode(data or {}), now + math.ceil(seconds), now,
    })
end

---Removes an order; returns false if someone else took it first.
---@param id integer
---@return boolean
function orders.close(id)
    local changed = MySQL.update.await('DELETE FROM `city_mining_orders` WHERE `id` = ?', { id })

    return (changed or 0) > 0
end

---Every open order of a character, for the app.
---@param citizenid string
---@return table[]
function orders.list(citizenid)
    local rows = MySQL.query.await('SELECT `id`, `place`, `recipe`, `count`, `ready_at` FROM `city_mining_orders` WHERE `citizenid` = ?', { citizenid }) or {}

    return rows
end

---Orders left uncollected for too long are dropped (once at start).
---@param hours number
function orders.expire(hours)
    MySQL.prepare.await('DELETE FROM `city_mining_orders` WHERE `ready_at` < ?', { os.time() - math.floor(hours * 3600) })
end

return orders
