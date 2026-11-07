-- What readers do: like an article and comment on it (with their character's name)
local common = require 'server.common'

local function exists(id)
    return MySQL.scalar.await('SELECT 1 FROM `phone_news_articles` WHERE `id` = ?', { id }) ~= nil
end

lib.callback.register('city_phone_news:like', function(source, id, liked)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id or common.throttled(src, 'like', 300) or not exists(id) then return false end

    local citizenid = player.PlayerData.citizenid

    if liked == true then
        MySQL.insert.await('INSERT IGNORE INTO `phone_news_likes` (`article_id`, `citizenid`) VALUES (?, ?)', { id, citizenid })
    else
        MySQL.update.await('DELETE FROM `phone_news_likes` WHERE `article_id` = ? AND `citizenid` = ?', { id, citizenid })
    end

    return true
end)

lib.callback.register('city_phone_news:comments', function(source, id, before)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id then return end

    local sql = [[
        SELECT c.`id`, c.`name`, c.`text`, c.`created_at` AS `createdAt`, c.`citizenid` = ? AS `mine`, a.`citizenid` = ? AS `onMine`
        FROM `phone_news_comments` c JOIN `phone_news_articles` a ON a.`id` = c.`article_id` WHERE c.`article_id` = ?
    ]]
    local citizenid = player.PlayerData.citizenid
    local params = { citizenid, citizenid, id }

    before = common.int(before)
    if before then
        sql = sql .. ' AND c.`id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.CommentPage

    local rights = common.rights(src)
    local rows = MySQL.query.await(sql .. ' ORDER BY c.`id` DESC LIMIT ?', params) or {}

    -- The writer, the article's author, the paper's boss and staff may delete a comment
    for _, row in ipairs(rows) do
        row.canDelete = row.mine == 1 or row.onMine == 1 or row.mine == true or row.onMine == true or rights.boss or rights.staff
        row.mine, row.onMine = nil, nil
    end

    return rows
end)

lib.callback.register('city_phone_news:comment', function(source, id, text)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    text = common.text(text, Config.CommentLength)
    if not player or not id or not text or text == '' or not common.hasPhone(src) then return false, 'invalid' end
    if common.throttled(src, 'comment', 3000) then return false, 'slow' end
    if not exists(id) then return false, 'invalid' end

    return MySQL.insert.await('INSERT INTO `phone_news_comments` (`article_id`, `citizenid`, `name`, `text`, `created_at`) VALUES (?, ?, ?, ?, ?)', {
        id, player.PlayerData.citizenid, common.name(player), text, os.time(),
    }) ~= nil
end)

lib.callback.register('city_phone_news:deleteComment', function(source, id)
    local src = source
    local player = common.player(src)
    id = common.int(id)
    if not player or not id or common.throttled(src, 'delete', 500) then return false end

    local comment = MySQL.single.await([[
        SELECT c.`citizenid`, c.`text`, a.`citizenid` AS `author` FROM `phone_news_comments` c
        JOIN `phone_news_articles` a ON a.`id` = c.`article_id` WHERE c.`id` = ?
    ]], { id })
    if not comment then return false end

    local citizenid = player.PlayerData.citizenid
    local rights = common.rights(src)
    local own = comment.citizenid == citizenid or comment.author == citizenid

    if not own and not rights.boss and not rights.staff then
        lib.print.warn(('city_phone_news: %s tried to delete comment %d'):format(src, id))
        return false
    end

    MySQL.update.await('DELETE FROM `phone_news_comments` WHERE `id` = ?', { id })

    if not own and not rights.boss then common.staffLog(src, 'news_remove_comment', comment.citizenid, comment.text) end

    return true
end)
