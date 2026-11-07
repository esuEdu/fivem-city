-- Accounts: one per character (@username, name, bio, profile photo), profiles and finding people
local common = require 'server.common'

---@param value unknown
---@return string?
local function username(value)
    if type(value) ~= 'string' then return end

    local name = value:lower()
    local length = #name

    if length < Config.UsernameLength.min or length > Config.UsernameLength.max then return end
    if not name:find('^[a-z0-9._]+$') then return end

    return name
end

-- The caller's account, or nothing yet (the page then asks them to make one)
lib.callback.register('city_phone_social:me', function(source)
    local src = source
    local account = common.account(src)
    if not account then return { account = false, staff = common.isStaff(src) } end

    return { account = { username = account.username, name = account.name }, staff = common.isStaff(src) }
end)

lib.callback.register('city_phone_social:createAccount', function(source, wanted, name)
    local src = source
    local citizenid = common.citizenid(src)
    if not citizenid or common.throttled(src, 'account', 2000) then return false, 'invalid' end
    if common.account(src) then return false, 'invalid' end

    wanted = username(wanted)
    name = common.text(name, Config.NameLength)
    if not wanted then return false, 'username' end
    if not name or name == '' then return false, 'name' end

    if MySQL.scalar.await('SELECT 1 FROM `phone_social_accounts` WHERE `username` = ?', { wanted }) then return false, 'taken' end

    local ok = pcall(MySQL.insert.await, 'INSERT INTO `phone_social_accounts` (`citizenid`, `username`, `name`, `created_at`) VALUES (?, ?, ?, ?)', {
        citizenid, wanted, name, os.time(),
    })

    -- two people asking for the same name at once: the unique key refuses the second
    if not ok then return false, 'taken' end

    return true
end)

-- avatar: a photo id to use, false to remove it, nil to keep it
lib.callback.register('city_phone_social:editProfile', function(source, name, bio, avatar)
    local src = source
    local account = common.account(src)
    if not account or common.throttled(src, 'account', 2000) then return false end

    name = common.text(name, Config.NameLength)
    bio = common.text(bio, Config.BioLength, true)
    if not name or name == '' or not bio then return false end

    if avatar == nil then
        return MySQL.update.await('UPDATE `phone_social_accounts` SET `name` = ?, `bio` = ? WHERE `citizenid` = ?', { name, bio, account.citizenid }) >= 0
    end

    local image = nil
    if avatar ~= false then
        image = common.photo(account.citizenid, avatar)
        if not image then return false end
    end

    return MySQL.update.await('UPDATE `phone_social_accounts` SET `name` = ?, `bio` = ?, `avatar` = ? WHERE `citizenid` = ?', {
        name, bio, image, account.citizenid,
    }) >= 0
end)

lib.callback.register('city_phone_social:avatar', function(source, wanted)
    if not common.citizenid(source) then return end

    wanted = username(wanted)
    if not wanted then return end

    common.wait()
    return MySQL.scalar.await('SELECT `avatar` FROM `phone_social_accounts` WHERE `username` = ?', { wanted })
end)

lib.callback.register('city_phone_social:profile', function(source, wanted)
    local src = source
    local me = common.account(src)
    wanted = username(wanted)
    if not me or not wanted then return end

    local account = MySQL.single.await([[
        SELECT a.`citizenid`, a.`username`, a.`name`, a.`bio`, (a.`avatar` IS NOT NULL) AS `has_avatar`,
            (SELECT COUNT(*) FROM `phone_social_posts` p WHERE p.`citizenid` = a.`citizenid` AND p.`kind` = 'post') AS `posts`,
            (SELECT COUNT(*) FROM `phone_social_follows` f WHERE f.`followed` = a.`citizenid`) AS `followers`,
            (SELECT COUNT(*) FROM `phone_social_follows` f WHERE f.`follower` = a.`citizenid`) AS `following`,
            EXISTS(SELECT 1 FROM `phone_social_follows` f WHERE f.`follower` = ? AND f.`followed` = a.`citizenid`) AS `followed`
        FROM `phone_social_accounts` a WHERE a.`username` = ?
    ]], { me.citizenid, wanted })

    if not account then return end

    return {
        username = account.username,
        name = account.name,
        bio = account.bio,
        posts = account.posts,
        followers = account.followers,
        following = account.following,
        followed = account.followed == 1 or account.followed == true,
        mine = account.citizenid == me.citizenid,
    }
end)

-- Finding people by @username or name
lib.callback.register('city_phone_social:search', function(source, query)
    local src = source
    if not common.account(src) or common.throttled(src, 'search', 250) then return end

    query = common.text(query, Config.UsernameLength.max)
    if not query or query == '' then return {} end

    local like = ('%s%%'):format(query:lower():gsub('[%%_\\]', '\\%0'))

    return MySQL.query.await([[
        SELECT `username`, `name` FROM `phone_social_accounts`
        WHERE `username` LIKE ? OR `name` LIKE ? ORDER BY `username` LIMIT 20
    ]], { like, like }) or {}
end)
