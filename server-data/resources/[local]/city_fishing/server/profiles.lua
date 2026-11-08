-- Fishing profile per character (XP, level, skills, stats) and the collection (species, count, best size), kept in
-- memory while the character is online and written on every change.
local levels = require 'shared.levels'

local profiles = {}

---@type table<string, table>
local cache = {}

function profiles.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_fishing_profiles` (
            `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
            `xp` INT NOT NULL DEFAULT 0,
            `skills` LONGTEXT NULL,
            `caught` INT NOT NULL DEFAULT 0,
            `legendaries` INT NOT NULL DEFAULT 0,
            `biggest` VARCHAR(80) NULL
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_fishing_collection` (
            `citizenid` VARCHAR(50) NOT NULL,
            `species` VARCHAR(50) NOT NULL,
            `count` INT NOT NULL DEFAULT 0,
            `best` INT NOT NULL DEFAULT 0,
            `first_at` INT NOT NULL,
            PRIMARY KEY (`citizenid`, `species`)
        )
    ]])
end

---@param citizenid string
---@return table
function profiles.get(citizenid)
    if cache[citizenid] then return cache[citizenid] end

    local row = MySQL.single.await('SELECT `xp`, `skills`, `caught`, `legendaries`, `biggest` FROM `city_fishing_profiles` WHERE `citizenid` = ?', { citizenid })
    local skills = row and row.skills and json.decode(row.skills)
    local xp = row and row.xp or 0

    local profile = {
        citizenid = citizenid,
        xp = xp,
        level = levels.fromXp(xp),
        skills = levels.clean(skills),
        caught = row and row.caught or 0,
        legendaries = row and row.legendaries or 0,
        biggest = row and row.biggest and json.decode(row.biggest) or nil,
    }

    cache[citizenid] = profile

    return profile
end

---@param profile table
local function save(profile)
    MySQL.prepare.await([[
        INSERT INTO `city_fishing_profiles` (`citizenid`, `xp`, `skills`, `caught`, `legendaries`, `biggest`) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `xp` = VALUES(`xp`), `skills` = VALUES(`skills`), `caught` = VALUES(`caught`),
            `legendaries` = VALUES(`legendaries`), `biggest` = VALUES(`biggest`)
    ]], {
        profile.citizenid, profile.xp, json.encode(profile.skills), profile.caught, profile.legendaries,
        profile.biggest and json.encode(profile.biggest) or nil,
    })
end

profiles.save = save

---Adds XP and returns the new level when it went up.
---@param profile table
---@param amount integer
---@return integer? newLevel
function profiles.addXp(profile, amount)
    local before = profile.level

    profile.xp = profile.xp + math.max(0, math.floor(amount))
    profile.level = levels.fromXp(profile.xp)
    save(profile)

    return profile.level > before and profile.level or nil
end

---Counts a catch in the stats and the collection.
---@param profile table
---@param entry table fish entry
---@param size integer? cm (fish only)
---@return boolean record a new best size for this species
function profiles.record(profile, entry, size)
    profile.caught = profile.caught + 1
    if entry.legendary then profile.legendaries = profile.legendaries + 1 end

    if size and (not profile.biggest or size > profile.biggest.size) and entry.kind == 'fish' then
        profile.biggest = { species = entry.name, size = size }
    end

    local row = MySQL.single.await('SELECT `best` FROM `city_fishing_collection` WHERE `citizenid` = ? AND `species` = ?', { profile.citizenid, entry.name })
    local record = size ~= nil and (not row or size > row.best)

    MySQL.prepare.await([[
        INSERT INTO `city_fishing_collection` (`citizenid`, `species`, `count`, `best`, `first_at`) VALUES (?, ?, 1, ?, ?)
        ON DUPLICATE KEY UPDATE `count` = `count` + 1, `best` = GREATEST(`best`, VALUES(`best`))
    ]], { profile.citizenid, entry.name, size or 0, os.time() })

    return record and row ~= nil
end

---@param citizenid string
---@return table[]
function profiles.collection(citizenid)
    return MySQL.query.await('SELECT `species`, `count`, `best`, `first_at` FROM `city_fishing_collection` WHERE `citizenid` = ?', { citizenid }) or {}
end

---@param citizenid string
function profiles.forget(citizenid)
    cache[citizenid] = nil
end

return profiles
