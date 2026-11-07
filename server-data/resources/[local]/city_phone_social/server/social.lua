-- Likes, comments and follows, with a phone notification to the person they are about
local common = require 'server.common'

local lastComment = {}

---@return table? post { citizenid }
local function postOf(id)
    return MySQL.single.await([[SELECT `citizenid` FROM `phone_social_posts` WHERE `id` = ? AND `kind` = 'post']], { id })
end

lib.callback.register('city_phone_social:like', function(source, id, liked)
    local src = source
    local me = common.account(src)
    id = common.int(id)
    if not me or not id or common.throttled(src, 'like', 300) then return false end

    local post = postOf(id)
    if not post then return false end

    if liked ~= true then
        MySQL.update.await('DELETE FROM `phone_social_likes` WHERE `post_id` = ? AND `citizenid` = ?', { id, me.citizenid })
        return true
    end

    local added = MySQL.update.await('INSERT IGNORE INTO `phone_social_likes` (`post_id`, `citizenid`) VALUES (?, ?)', { id, me.citizenid })
    if added > 0 then common.notify(post.citizenid, me.citizenid, ('@%s liked your post'):format(me.username)) end

    return true
end)

lib.callback.register('city_phone_social:comments', function(source, id, before)
    local src = source
    local me = common.account(src)
    id = common.int(id)
    if not me or not id then return end

    local post = postOf(id)
    if not post then return end

    local sql = [[
        SELECT c.`id`, c.`text`, c.`created_at` AS `createdAt`, a.`username`, c.`citizenid` = ? AS `mine`
        FROM `phone_social_comments` c JOIN `phone_social_accounts` a ON a.`citizenid` = c.`citizenid`
        WHERE c.`post_id` = ?
    ]]
    local params = { me.citizenid, id }

    before = common.int(before)
    if before then
        sql = sql .. ' AND c.`id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.CommentPage

    local rows = MySQL.query.await(sql .. ' ORDER BY c.`id` DESC LIMIT ?', params) or {}
    local postMine = post.citizenid == me.citizenid

    -- The post's owner may delete any comment on it
    for _, row in ipairs(rows) do
        row.mine = row.mine == 1 or row.mine == true
        row.canDelete = row.mine or postMine
    end

    return rows
end)

lib.callback.register('city_phone_social:comment', function(source, id, text)
    local src = source
    local me = common.account(src)
    id = common.int(id)
    text = common.text(text, Config.CommentLength)
    if not me or not id or not text or text == '' then return false, 'invalid' end

    local now = os.time()
    if lastComment[src] and now - lastComment[src] < Config.CommentCooldown then return false, 'slow' end

    local post = postOf(id)
    if not post then return false, 'invalid' end

    lastComment[src] = now

    MySQL.insert.await('INSERT INTO `phone_social_comments` (`post_id`, `citizenid`, `text`, `created_at`) VALUES (?, ?, ?, ?)', {
        id, me.citizenid, text, now,
    })

    common.notify(post.citizenid, me.citizenid, ('@%s commented: %s'):format(me.username, text:sub(1, 80)))

    return true
end)

-- The comment's writer, the post's owner, or staff (logged)
lib.callback.register('city_phone_social:deleteComment', function(source, id)
    local src = source
    local me = common.account(src)
    id = common.int(id)
    if not me or not id or common.throttled(src, 'delete', 500) then return false end

    local comment = MySQL.single.await([[
        SELECT c.`citizenid`, c.`text`, p.`citizenid` AS `owner` FROM `phone_social_comments` c
        JOIN `phone_social_posts` p ON p.`id` = c.`post_id` WHERE c.`id` = ?
    ]], { id })
    if not comment then return false end

    local allowed = comment.citizenid == me.citizenid or comment.owner == me.citizenid
    local staff = not allowed and common.isStaff(src)

    if not allowed and not staff then
        lib.print.warn(('city_phone_social: %s tried to delete comment %d'):format(src, id))
        return false
    end

    MySQL.update.await('DELETE FROM `phone_social_comments` WHERE `id` = ?', { id })

    if staff then common.staffLog(src, 'social_remove_comment', comment.citizenid, comment.text) end

    return true
end)

lib.callback.register('city_phone_social:follow', function(source, username, follow)
    local src = source
    local me = common.account(src)
    if not me or type(username) ~= 'string' or common.throttled(src, 'follow', 500) then return false end

    local target = MySQL.scalar.await('SELECT `citizenid` FROM `phone_social_accounts` WHERE `username` = ?', { username:lower() })
    if not target or target == me.citizenid then return false end

    if follow ~= true then
        MySQL.update.await('DELETE FROM `phone_social_follows` WHERE `follower` = ? AND `followed` = ?', { me.citizenid, target })
        return true
    end

    local added = MySQL.update.await('INSERT IGNORE INTO `phone_social_follows` (`follower`, `followed`, `created_at`) VALUES (?, ?, ?)', {
        me.citizenid, target, os.time(),
    })

    if added > 0 then common.notify(target, me.citizenid, ('@%s started following you'):format(me.username)) end

    return true
end)

AddEventHandler('playerDropped', function()
    lastComment[source] = nil
end)
