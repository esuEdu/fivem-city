-- The ads and favorites tables. Only the server reads or writes them; every query is per character or per ad.
local store = {}

local ready = promise.new()

local COLUMNS = 'a.`id`, a.`citizenid`, a.`title`, a.`description`, a.`price`, a.`category`, a.`number`, '
    .. 'a.`show_number`, (a.`photo` IS NOT NULL) AS `has_photo`, a.`created_at`, a.`expires_at`'

function store.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_market_ads` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `title` VARCHAR(50) NOT NULL,
            `description` VARCHAR(500) NOT NULL DEFAULT '',
            `price` INT NOT NULL DEFAULT 0,
            `category` VARCHAR(20) NOT NULL,
            `number` VARCHAR(20) NOT NULL,
            `show_number` TINYINT(1) NOT NULL DEFAULT 1,
            `photo` MEDIUMTEXT NULL,
            `created_at` INT NOT NULL,
            `expires_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `expires_at` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_market_favorites` (
            `citizenid` VARCHAR(50) NOT NULL,
            `ad_id` INT NOT NULL,
            PRIMARY KEY (`citizenid`, `ad_id`),
            KEY `ad_id` (`ad_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

local function wait()
    if ready.state == 0 then Citizen.Await(ready) end
end

---@param row table
local function shape(row)
    row.show_number = row.show_number == true or row.show_number == 1
    row.has_photo = row.has_photo == true or row.has_photo == 1
    return row
end

---@param rows table[]?
---@return table[]
local function shapeAll(rows)
    rows = rows or {}
    for i = 1, #rows do shape(rows[i]) end
    return rows
end

---Ads up now, newest first, optionally of one category and matching a search, older than `before` (paging)
---@param category string?
---@param search string?
---@param before integer?
function store.list(category, search, before)
    wait()

    local sql = ('SELECT %s FROM `phone_market_ads` a WHERE `expires_at` > ?'):format(COLUMNS)
    local params = { os.time() }

    if category then
        sql = sql .. ' AND `category` = ?'
        params[#params + 1] = category
    end

    if search then
        sql = sql .. ' AND (`title` LIKE ? OR `description` LIKE ?)'
        local like = ('%%%s%%'):format(search:gsub('[%%_\\]', '\\%0'))
        params[#params + 1] = like
        params[#params + 1] = like
    end

    if before then
        sql = sql .. ' AND `id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.PageSize

    return shapeAll(MySQL.query.await(sql .. ' ORDER BY `id` DESC LIMIT ?', params))
end

---A character's own ads, expired ones too
function store.mine(citizenid)
    wait()
    return shapeAll(MySQL.query.await(('SELECT %s FROM `phone_market_ads` a WHERE `citizenid` = ? ORDER BY `id` DESC'):format(COLUMNS), { citizenid }))
end

function store.favorites(citizenid)
    wait()
    return shapeAll(MySQL.query.await(([[
        SELECT %s FROM `phone_market_ads` a JOIN `phone_market_favorites` f ON f.`ad_id` = a.`id`
        WHERE f.`citizenid` = ? AND a.`expires_at` > ? ORDER BY a.`id` DESC
    ]]):format(COLUMNS), { citizenid, os.time() }))
end

function store.favoriteIds(citizenid)
    wait()
    local rows = MySQL.query.await('SELECT `ad_id` FROM `phone_market_favorites` WHERE `citizenid` = ?', { citizenid }) or {}
    local ids = {}
    for i = 1, #rows do ids[i] = rows[i].ad_id end
    return ids
end

function store.get(id)
    wait()
    local row = MySQL.single.await(('SELECT %s FROM `phone_market_ads` a WHERE `id` = ?'):format(COLUMNS), { id })
    return row and shape(row)
end

function store.photo(id)
    wait()
    return MySQL.scalar.await('SELECT `photo` FROM `phone_market_ads` WHERE `id` = ? AND `expires_at` > ?', { id, os.time() })
end

function store.countActive(citizenid)
    wait()
    return MySQL.scalar.await('SELECT COUNT(*) FROM `phone_market_ads` WHERE `citizenid` = ? AND `expires_at` > ?', { citizenid, os.time() }) or 0
end

---@param ad { citizenid: string, title: string, description: string, price: integer, category: string, number: string, show_number: boolean, photo: string? }
function store.add(ad)
    wait()
    local now = os.time()

    return MySQL.insert.await([[
        INSERT INTO `phone_market_ads` (`citizenid`, `title`, `description`, `price`, `category`, `number`, `show_number`, `photo`, `created_at`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { ad.citizenid, ad.title, ad.description, ad.price, ad.category, ad.number, ad.show_number and 1 or 0, ad.photo, now, now + Config.Days * 86400 })
end

---Editing keeps the photo unless a new one is given (keepPhoto false and photo nil removes it)
function store.update(citizenid, id, ad, keepPhoto)
    wait()

    if keepPhoto then
        return MySQL.update.await([[
            UPDATE `phone_market_ads` SET `title` = ?, `description` = ?, `price` = ?, `category` = ?, `show_number` = ?
            WHERE `id` = ? AND `citizenid` = ?
        ]], { ad.title, ad.description, ad.price, ad.category, ad.show_number and 1 or 0, id, citizenid }) > 0
    end

    return MySQL.update.await([[
        UPDATE `phone_market_ads` SET `title` = ?, `description` = ?, `price` = ?, `category` = ?, `show_number` = ?, `photo` = ?
        WHERE `id` = ? AND `citizenid` = ?
    ]], { ad.title, ad.description, ad.price, ad.category, ad.show_number and 1 or 0, ad.photo, id, citizenid }) > 0
end

function store.renew(citizenid, id)
    wait()
    return MySQL.update.await('UPDATE `phone_market_ads` SET `expires_at` = ? WHERE `id` = ? AND `citizenid` = ?', {
        os.time() + Config.Days * 86400, id, citizenid,
    }) > 0
end

---Deletes an ad and the favorites pointing at it. citizenid nil = any owner (staff).
function store.delete(id, citizenid)
    wait()

    local removed = citizenid
        and MySQL.update.await('DELETE FROM `phone_market_ads` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
        or MySQL.update.await('DELETE FROM `phone_market_ads` WHERE `id` = ?', { id })

    if removed > 0 then MySQL.update('DELETE FROM `phone_market_favorites` WHERE `ad_id` = ?', { id }) end

    return removed > 0
end

function store.setFavorite(citizenid, id, favorite)
    wait()

    if favorite then
        return MySQL.insert.await('INSERT IGNORE INTO `phone_market_favorites` (`citizenid`, `ad_id`) VALUES (?, ?)', { citizenid, id }) ~= nil
    end

    return MySQL.update.await('DELETE FROM `phone_market_favorites` WHERE `citizenid` = ? AND `ad_id` = ?', { citizenid, id }) >= 0
end

---Ads expired for longer than Config.KeepExpiredDays, and their favorites
function store.purge()
    wait()
    local cutoff = os.time() - Config.KeepExpiredDays * 86400

    MySQL.update.await('DELETE f FROM `phone_market_favorites` f JOIN `phone_market_ads` a ON a.`id` = f.`ad_id` WHERE a.`expires_at` < ?', { cutoff })
    MySQL.update.await('DELETE FROM `phone_market_ads` WHERE `expires_at` < ?', { cutoff })
end

return store
