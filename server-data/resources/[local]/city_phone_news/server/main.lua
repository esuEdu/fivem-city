-- Articles: the list (by category, newest first, breaking news on top while fresh), one article, and writing,
-- editing and deleting them. Only journalists on duty write; breaking news notifies every phone.
local common = require 'server.common'

local CATEGORIES = {}
for _, category in ipairs(Config.Categories) do CATEGORIES[category] = true end

local lastBreaking = {}

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_news_articles` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `author` VARCHAR(60) NOT NULL,
            `title` VARCHAR(80) NOT NULL,
            `body` TEXT NOT NULL,
            `category` VARCHAR(20) NOT NULL,
            `breaking` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` INT NOT NULL,
            `updated_at` INT NULL,
            PRIMARY KEY (`id`),
            KEY `category` (`category`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_news_likes` (
            `article_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            PRIMARY KEY (`article_id`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_news_comments` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `article_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(60) NOT NULL,
            `text` VARCHAR(300) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `article_id` (`article_id`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    common.setReady()
end)

local function yes(value)
    return value == 1 or value == true
end

---@param data unknown
---@return table? article { title, body, category, breaking }
local function readArticle(data)
    if type(data) ~= 'table' then return end

    local title = common.text(data.title, Config.TitleLength)
    local body = common.text(data.body, Config.BodyLength, true)
    if not title or title == '' or not body or body == '' or not CATEGORIES[data.category] then return end

    return { title = title, body = body, category = data.category, breaking = data.breaking == true }
end

lib.callback.register('city_phone_news:list', function(source, category, before)
    local src = source
    local player = common.player(src)
    if not player or common.throttled(src, 'list', 200) then return end

    common.wait()

    local sql = [[
        SELECT a.`id`, a.`author`, a.`title`, LEFT(a.`body`, 140) AS `preview`, a.`category`, a.`breaking`, a.`created_at` AS `createdAt`,
            (SELECT COUNT(*) FROM `phone_news_likes` l WHERE l.`article_id` = a.`id`) AS `likes`,
            (SELECT COUNT(*) FROM `phone_news_comments` c WHERE c.`article_id` = a.`id`) AS `comments`
        FROM `phone_news_articles` a WHERE 1 = 1
    ]]
    local params = {}

    if CATEGORIES[category] then
        sql = sql .. ' AND a.`category` = ?'
        params[#params + 1] = category
    end

    before = common.int(before)
    if before then
        sql = sql .. ' AND a.`id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.PageSize

    local rows = MySQL.query.await(sql .. ' ORDER BY a.`id` DESC LIMIT ?', params) or {}
    for _, row in ipairs(rows) do row.breaking = yes(row.breaking) end

    return { articles = rows, rights = common.rights(src) }
end)

lib.callback.register('city_phone_news:article', function(source, id)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id then return end

    common.wait()

    local row = MySQL.single.await([[
        SELECT a.`id`, a.`citizenid`, a.`author`, a.`title`, a.`body`, a.`category`, a.`breaking`,
            a.`created_at` AS `createdAt`, a.`updated_at` AS `updatedAt`,
            (SELECT COUNT(*) FROM `phone_news_likes` l WHERE l.`article_id` = a.`id`) AS `likes`,
            EXISTS(SELECT 1 FROM `phone_news_likes` l WHERE l.`article_id` = a.`id` AND l.`citizenid` = ?) AS `liked`
        FROM `phone_news_articles` a WHERE a.`id` = ?
    ]], { player.PlayerData.citizenid, id })

    if not row then return end

    local rights = common.rights(src)
    local mine = row.citizenid == player.PlayerData.citizenid

    row.breaking = yes(row.breaking)
    row.liked = yes(row.liked)
    row.canEdit = mine and rights.write
    row.canDelete = mine or rights.boss or rights.staff
    row.citizenid = nil

    return row
end)

---Every player online gets a phone notification
local function broadcast(title)
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        exports.city_phone:Notify(player.PlayerData.source, { app = 'news', title = 'Weazel News · BREAKING', text = title })
    end
end

lib.callback.register('city_phone_news:publish', function(source, data)
    local src = source
    local player = common.player(src)
    if not player or not common.hasPhone(src) or common.throttled(src, 'write', 3000) then return false, 'invalid' end

    if not common.rights(src).write then
        lib.print.warn(('city_phone_news: %s tried to publish without being a journalist on duty'):format(src))
        return false, 'denied'
    end

    local article = readArticle(data)
    if not article then return false, 'invalid' end

    local now = os.time()
    if article.breaking and lastBreaking[player.PlayerData.citizenid] and now - lastBreaking[player.PlayerData.citizenid] < Config.BreakingCooldown * 60 then
        return false, 'breaking'
    end

    local id = MySQL.insert.await([[
        INSERT INTO `phone_news_articles` (`citizenid`, `author`, `title`, `body`, `category`, `breaking`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { player.PlayerData.citizenid, common.name(player), article.title, article.body, article.category, article.breaking and 1 or 0, now })

    if not id then return false, 'invalid' end

    if article.breaking then
        lastBreaking[player.PlayerData.citizenid] = now
        broadcast(article.title)
    end

    return id
end)

-- Only the author, still a journalist on duty; editing never sends breaking news again
lib.callback.register('city_phone_news:edit', function(source, id, data)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id or common.throttled(src, 'write', 3000) or not common.rights(src).write then return false, 'denied' end

    local article = readArticle(data)
    if not article then return false, 'invalid' end

    return MySQL.update.await([[
        UPDATE `phone_news_articles` SET `title` = ?, `body` = ?, `category` = ?, `updated_at` = ? WHERE `id` = ? AND `citizenid` = ?
    ]], { article.title, article.body, article.category, os.time(), id, player.PlayerData.citizenid }) > 0
end)

-- The author, the paper's boss, or staff (logged)
lib.callback.register('city_phone_news:delete', function(source, id)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id or common.throttled(src, 'delete', 1000) then return false end

    local article = MySQL.single.await('SELECT `citizenid`, `title` FROM `phone_news_articles` WHERE `id` = ?', { id })
    if not article then return false end

    local rights = common.rights(src)
    local mine = article.citizenid == player.PlayerData.citizenid

    if not mine and not rights.boss and not rights.staff then
        lib.print.warn(('city_phone_news: %s tried to delete article %d'):format(src, id))
        return false
    end

    MySQL.update.await('DELETE FROM `phone_news_articles` WHERE `id` = ?', { id })
    MySQL.update('DELETE FROM `phone_news_likes` WHERE `article_id` = ?', { id })
    MySQL.update('DELETE FROM `phone_news_comments` WHERE `article_id` = ?', { id })

    if not mine and not rights.boss then common.staffLog(src, 'news_remove_article', article.citizenid, article.title) end

    return true
end)
