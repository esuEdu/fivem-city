-- The player's own profile: making it, editing it (name, bio, who they want to see, up to 3 photos), deleting it,
-- and any profile's photos. Age and gender always come from the character.
local common = require 'server.common'

local INTERESTS = { men = true, women = true, everyone = true }

---@param profileId integer
---@return integer[] slots that have a photo
local function slots(profileId)
    local rows = MySQL.query.await('SELECT `slot` FROM `phone_dating_photos` WHERE `profile_id` = ? ORDER BY `slot`', { profileId }) or {}
    local list = {}
    for i = 1, #rows do list[i] = rows[i].slot end
    return list
end

lib.callback.register('city_phone_dating:me', function(source)
    local src = source
    local player = common.player(src)
    if not player then return end

    local profile = common.profile(src)
    if not profile then return { profile = false } end

    local row = MySQL.single.await('SELECT `name`, `bio`, `age`, `interest` FROM `phone_dating_profiles` WHERE `id` = ?', { profile.id })

    return {
        profile = { id = profile.id, name = row.name, bio = row.bio, age = row.age, interest = row.interest, photos = slots(profile.id) },
    }
end)

-- data: { name, bio, interest, photos = { [1..3] = 'keep' | false | photo id } }
lib.callback.register('city_phone_dating:save', function(source, data)
    local src = source
    local player = common.player(src)
    if not player or type(data) ~= 'table' or common.throttled(src, 'save', 2000) then return false, 'invalid' end

    local name = common.text(data.name, Config.NameLength)
    local bio = common.text(data.bio or '', Config.BioLength, true)
    local interest = INTERESTS[data.interest] and data.interest or nil
    local photos = type(data.photos) == 'table' and data.photos or {}

    if not name or name == '' then return false, 'name' end
    if not bio or not interest then return false, 'invalid' end

    local citizenid = player.PlayerData.citizenid
    local charinfo = player.PlayerData.charinfo
    local age = common.age(charinfo.birthdate)
    local gender = tonumber(charinfo.gender) == 1 and 1 or 0

    -- Read every new photo first, so a bad id changes nothing
    local new, remove = {}, {}
    for slot = 1, Config.MaxPhotos do
        local value = photos[slot]

        if value == false then
            remove[#remove + 1] = slot
        elseif value ~= nil and value ~= 'keep' then
            local image = common.photo(citizenid, value)
            if not image then return false, 'invalid' end
            new[slot] = image
        end
    end

    local profile = common.profile(src)
    local id = profile and profile.id

    -- A new profile needs at least one photo
    if not id and next(new) == nil then return false, 'photo' end

    if id then
        MySQL.update.await('UPDATE `phone_dating_profiles` SET `name` = ?, `bio` = ?, `age` = ?, `gender` = ?, `interest` = ? WHERE `id` = ?', {
            name, bio, age, gender, interest, id,
        })
    else
        id = MySQL.insert.await('INSERT INTO `phone_dating_profiles` (`citizenid`, `name`, `bio`, `age`, `gender`, `interest`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            citizenid, name, bio, age, gender, interest, os.time(),
        })
        if not id then return false, 'invalid' end
    end

    for _, slot in ipairs(remove) do
        MySQL.update.await('DELETE FROM `phone_dating_photos` WHERE `profile_id` = ? AND `slot` = ?', { id, slot })
    end

    for slot, image in pairs(new) do
        MySQL.insert.await('REPLACE INTO `phone_dating_photos` (`profile_id`, `slot`, `image`) VALUES (?, ?, ?)', { id, slot, image })
    end

    return true
end)

-- Deleting the profile takes its photos, likes, matches and chats with it
lib.callback.register('city_phone_dating:deleteProfile', function(source)
    local src = source
    local profile = common.profile(src)
    if not profile or common.throttled(src, 'save', 2000) then return false end

    local id = profile.id

    MySQL.update.await('DELETE m FROM `phone_dating_messages` m JOIN `phone_dating_matches` x ON x.`id` = m.`match_id` WHERE x.`a` = ? OR x.`b` = ?', { id, id })
    MySQL.update.await('DELETE FROM `phone_dating_matches` WHERE `a` = ? OR `b` = ?', { id, id })
    MySQL.update.await('DELETE FROM `phone_dating_swipes` WHERE `from_id` = ? OR `to_id` = ?', { id, id })
    MySQL.update.await('DELETE FROM `phone_dating_photos` WHERE `profile_id` = ?', { id })
    MySQL.update.await('DELETE FROM `phone_dating_profiles` WHERE `id` = ?', { id })

    return true
end)

-- Any profile's photo (they are what the cards show)
lib.callback.register('city_phone_dating:photo', function(source, profileId, slot)
    if not common.player(source) then return end

    profileId, slot = common.int(profileId), common.int(slot)
    if not profileId or not slot then return end

    common.wait()
    return MySQL.scalar.await('SELECT `image` FROM `phone_dating_photos` WHERE `profile_id` = ? AND `slot` = ?', { profileId, slot })
end)

-- The player's own photos to pick from: ids (newest first), then each image when shown
lib.callback.register('city_phone_dating:myPhotos', function(source)
    local player = common.player(source)
    if not player then return end

    local list = {}
    for _, photo in ipairs(exports.city_phone_photos:List(player.PlayerData.citizenid)) do
        list[#list + 1] = photo.id
        if #list >= 30 then break end
    end

    return list
end)

lib.callback.register('city_phone_dating:myPhoto', function(source, id)
    local player = common.player(source)
    if not player then return end

    return common.photo(player.PlayerData.citizenid, id)
end)
