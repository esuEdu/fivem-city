-- Mining profile per character (XP, level, skills, stats, today's dynamite), kept in memory while the character is
-- online. Changes are written every minute and when the player leaves, not on every vein.
local levels = require 'shared.levels'

local profiles = {}

---@type table<string, table>
local cache = {}
---@type table<string, boolean>
local dirty = {}
---@type table<string, number[]> vein timestamps in the last hour
local recent = {}

function profiles.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_mining_profiles` (
            `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
            `xp` INT NOT NULL DEFAULT 0,
            `skills` LONGTEXT NULL,
            `mined` INT NOT NULL DEFAULT 0,
            `geodes` INT NOT NULL DEFAULT 0,
            `panned` INT NOT NULL DEFAULT 0,
            `dynamite_day` VARCHAR(10) NULL,
            `dynamite_count` INT NOT NULL DEFAULT 0
        )
    ]])
end

---@param citizenid string
---@return table
function profiles.get(citizenid)
    if cache[citizenid] then return cache[citizenid] end

    local row = MySQL.single.await('SELECT `xp`, `skills`, `mined`, `geodes`, `panned`, `dynamite_day`, `dynamite_count` FROM `city_mining_profiles` WHERE `citizenid` = ?', { citizenid })
    local xp = row and row.xp or 0

    local profile = {
        citizenid = citizenid,
        xp = xp,
        level = levels.fromXp(xp),
        skills = levels.clean(row and row.skills and json.decode(row.skills)),
        mined = row and row.mined or 0,
        geodes = row and row.geodes or 0,
        panned = row and row.panned or 0,
        dynamiteDay = row and row.dynamite_day or nil,
        dynamiteCount = row and row.dynamite_count or 0,
    }

    cache[citizenid] = profile

    return profile
end

---@param profile table
local function write(profile)
    MySQL.prepare.await([[
        INSERT INTO `city_mining_profiles` (`citizenid`, `xp`, `skills`, `mined`, `geodes`, `panned`, `dynamite_day`, `dynamite_count`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `xp` = VALUES(`xp`), `skills` = VALUES(`skills`), `mined` = VALUES(`mined`), `geodes` = VALUES(`geodes`),
            `panned` = VALUES(`panned`), `dynamite_day` = VALUES(`dynamite_day`), `dynamite_count` = VALUES(`dynamite_count`)
    ]], {
        profile.citizenid, profile.xp, json.encode(profile.skills), profile.mined, profile.geodes, profile.panned,
        profile.dynamiteDay, profile.dynamiteCount,
    })
end

---Marks a profile to be written on the next flush.
---@param profile table
function profiles.touch(profile)
    dirty[profile.citizenid] = true
end

---Writes a profile now (skills, purchases: things the player would notice losing).
---@param profile table
function profiles.save(profile)
    dirty[profile.citizenid] = nil
    write(profile)
end

---@param profile table
---@param id string skill id
---@return number
function profiles.skill(profile, id)
    return levels.value(profile.skills, id)
end

---Adds XP and returns the new level when it went up.
---@param profile table
---@param amount integer
---@return integer? newLevel
function profiles.addXp(profile, amount)
    if amount <= 0 then return end

    local before = profile.level
    profile.xp = profile.xp + math.floor(amount)
    profile.level = levels.fromXp(profile.xp)
    profiles.touch(profile)

    return profile.level > before and profile.level or nil
end

---Counts a vein and returns how many this character mined in the last hour (with this one).
---@param citizenid string
---@return integer
function profiles.countVein(citizenid)
    local now = os.time()
    local list = recent[citizenid] or {}
    local kept = {}

    for _, at in ipairs(list) do
        if now - at < 3600 then kept[#kept + 1] = at end
    end

    kept[#kept + 1] = now
    recent[citizenid] = kept

    return #kept
end

---@param citizenid string
---@return integer veins in the last hour
function profiles.recentVeins(citizenid)
    local now, count = os.time(), 0

    for _, at in ipairs(recent[citizenid] or {}) do
        if now - at < 3600 then count = count + 1 end
    end

    return count
end

function profiles.flush()
    for citizenid in pairs(dirty) do
        local profile = cache[citizenid]
        if profile then write(profile) end
        dirty[citizenid] = nil
    end
end

---@param citizenid string
function profiles.forget(citizenid)
    local profile = cache[citizenid]
    if profile and dirty[citizenid] then write(profile) end

    dirty[citizenid] = nil
    cache[citizenid] = nil
end

return profiles
