-- Posts and stories: publishing from the player's own photos, the feed (you and who you follow), explore (everyone),
-- a profile's posts, the stories bar, images, and deleting (the owner, or staff)
local common = require 'server.common'

local lastPost = {}

-- The columns a page sees for a post; the first ? is the viewer's citizenid (liked / mine)
local SELECT_POSTS = [[
    SELECT p.`id`, p.`caption`, p.`created_at`, a.`username`, a.`name`,
        (SELECT COUNT(*) FROM `phone_social_likes` l WHERE l.`post_id` = p.`id`) AS `likes`,
        (SELECT COUNT(*) FROM `phone_social_comments` c WHERE c.`post_id` = p.`id`) AS `comments`,
        EXISTS(SELECT 1 FROM `phone_social_likes` l WHERE l.`post_id` = p.`id` AND l.`citizenid` = ?) AS `liked`,
        p.`citizenid` = ? AS `mine`
    FROM `phone_social_posts` p JOIN `phone_social_accounts` a ON a.`citizenid` = p.`citizenid`
    WHERE p.`kind` = 'post'
]]

local function yes(value)
    return value == 1 or value == true
end

---@param rows table[]?
local function shape(rows)
    rows = rows or {}

    for _, row in ipairs(rows) do
        row.createdAt, row.created_at = row.created_at, nil
        row.liked = yes(row.liked)
        row.mine = yes(row.mine)
    end

    return rows
end

-- scope: 'feed' | 'explore' | 'user' (with username); before: the last id already shown
lib.callback.register('city_phone_social:posts', function(source, scope, username, before)
    local src = source
    local me = common.account(src)
    if not me or common.throttled(src, 'posts', 200) then return end

    local sql = SELECT_POSTS
    local params = { me.citizenid, me.citizenid }

    if scope == 'feed' then
        sql = sql .. ' AND (p.`citizenid` = ? OR p.`citizenid` IN (SELECT `followed` FROM `phone_social_follows` WHERE `follower` = ?))'
        params[#params + 1] = me.citizenid
        params[#params + 1] = me.citizenid
    elseif scope == 'user' and type(username) == 'string' then
        sql = sql .. ' AND a.`username` = ?'
        params[#params + 1] = username:lower()
    elseif scope ~= 'explore' then
        return
    end

    before = common.int(before)
    if before then
        sql = sql .. ' AND p.`id` < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = Config.PageSize

    return shape(MySQL.query.await(sql .. ' ORDER BY p.`id` DESC LIMIT ?', params))
end)

-- A post's or story's image (stories only while they are up)
lib.callback.register('city_phone_social:image', function(source, id)
    if not common.citizenid(source) then return end
    common.wait()

    id = common.int(id)
    if not id then return end

    return MySQL.scalar.await([[
        SELECT `image` FROM `phone_social_posts` WHERE `id` = ? AND (`kind` = 'post' OR `created_at` > ?)
    ]], { id, os.time() - Config.StoryHours * 3600 })
end)

-- Stories up now from you and who you follow, one entry per person (yours first), oldest story first
lib.callback.register('city_phone_social:stories', function(source)
    local src = source
    local me = common.account(src)
    if not me then return end

    local rows = MySQL.query.await([[
        SELECT p.`id`, p.`created_at`, p.`citizenid`, a.`username`, a.`name`
        FROM `phone_social_posts` p JOIN `phone_social_accounts` a ON a.`citizenid` = p.`citizenid`
        WHERE p.`kind` = 'story' AND p.`created_at` > ?
            AND (p.`citizenid` = ? OR p.`citizenid` IN (SELECT `followed` FROM `phone_social_follows` WHERE `follower` = ?))
        ORDER BY p.`id` ASC
    ]], { os.time() - Config.StoryHours * 3600, me.citizenid, me.citizenid }) or {}

    local people, byUser = {}, {}

    for _, row in ipairs(rows) do
        local person = byUser[row.username]

        if not person then
            person = { username = row.username, name = row.name, mine = row.citizenid == me.citizenid, stories = {} }
            byUser[row.username] = person

            if person.mine then table.insert(people, 1, person) else people[#people + 1] = person end
        end

        person.stories[#person.stories + 1] = { id = row.id, createdAt = row.created_at }
    end

    return people
end)

-- kind: 'post' or 'story'; photo: one of the player's photo ids (copied into the post)
lib.callback.register('city_phone_social:publish', function(source, kind, photo, caption)
    local src = source
    local me = common.account(src)
    if not me or not common.hasPhone(src) then return false, 'invalid' end
    if kind ~= 'post' and kind ~= 'story' then return false, 'invalid' end

    local now = os.time()
    if lastPost[src] and now - lastPost[src] < Config.PostCooldown then return false, 'slow' end

    local image = common.photo(me.citizenid, photo)
    caption = kind == 'post' and common.text(caption or '', Config.CaptionLength, true) or ''
    if not image or not caption then return false, 'invalid' end

    lastPost[src] = now

    return MySQL.insert.await('INSERT INTO `phone_social_posts` (`citizenid`, `kind`, `image`, `caption`, `created_at`) VALUES (?, ?, ?, ?, ?)', {
        me.citizenid, kind, image, caption, now,
    }) ~= nil
end)

-- The owner deletes their post or story; staff delete anyone's (logged)
lib.callback.register('city_phone_social:deletePost', function(source, id)
    local src = source
    local me = common.account(src)
    id = common.int(id)
    if not me or not id or common.throttled(src, 'delete', 500) then return false end

    local post = MySQL.single.await('SELECT `citizenid`, `kind`, `caption` FROM `phone_social_posts` WHERE `id` = ?', { id })
    if not post then return false end

    local own = post.citizenid == me.citizenid

    if not own and not common.isStaff(src) then
        lib.print.warn(('city_phone_social: %s tried to delete post %d without being its owner or staff'):format(src, id))
        return false
    end

    MySQL.update.await('DELETE FROM `phone_social_posts` WHERE `id` = ?', { id })
    MySQL.update('DELETE FROM `phone_social_likes` WHERE `post_id` = ?', { id })
    MySQL.update('DELETE FROM `phone_social_comments` WHERE `post_id` = ?', { id })

    if not own then common.staffLog(src, 'social_remove_post', post.citizenid, ('#%d %s'):format(id, post.caption)) end

    return true
end)

-- The player's own photos to pick one: ids (newest first), then each image when shown
lib.callback.register('city_phone_social:myPhotos', function(source)
    local citizenid = common.citizenid(source)
    if not citizenid then return end

    local list = {}
    for _, photo in ipairs(exports.city_phone_photos:List(citizenid)) do
        list[#list + 1] = photo.id
        if #list >= 30 then break end
    end

    return list
end)

lib.callback.register('city_phone_social:myPhoto', function(source, id)
    local citizenid = common.citizenid(source)
    if not citizenid then return end

    return common.photo(citizenid, id)
end)

AddEventHandler('playerDropped', function()
    lastPost[source] = nil
end)
