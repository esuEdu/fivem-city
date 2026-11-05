-- Each tablet's owner, settings and passcode, saved by serial (the tablet item's metadata). The passcode is a
-- bcrypt hash and never leaves the server.

local settings = require 'shared.settings'

local tablets = {}

local ready = promise.new()

---@class Tablet
---@field serial string
---@field owner string citizenid of the first player who opened it
---@field codeHash? string
---@field settings table
---@field tries integer wrong codes in a row
---@field waitUntil integer os.time() when the next try is allowed

---@type table<string, Tablet>
local cache = {}

function tablets.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_os_tablets` (
            `serial` VARCHAR(20) NOT NULL,
            `owner` VARCHAR(50) NOT NULL,
            `code_hash` VARCHAR(100) NULL,
            `settings` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`serial`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_os_unlocks` (
            `citizenid` VARCHAR(50) NOT NULL,
            `unlock_key` VARCHAR(32) NOT NULL,
            PRIMARY KEY (`citizenid`, `unlock_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

---A new serial like IFP-48213-KX.
---@return string
function tablets.newSerial()
    return ('IFP-%05d-%s'):format(math.random(0, 99999), lib.string.random('AA'))
end

---The tablet with this serial, created for `owner` if it's new. Yields.
---@param serial string
---@param owner string
---@return Tablet
function tablets.get(serial, owner)
    if cache[serial] then return cache[serial] end

    Citizen.Await(ready)

    local row = MySQL.single.await('SELECT `owner`, `code_hash`, `settings` FROM `city_os_tablets` WHERE `serial` = ?', { serial })
    local tablet

    if row then
        tablet = { serial = serial, owner = row.owner, codeHash = row.code_hash, settings = settings.sanitize(json.decode(row.settings)), tries = 0, waitUntil = 0 }
    else
        tablet = { serial = serial, owner = owner, settings = settings.sanitize(nil), tries = 0, waitUntil = 0 }
        MySQL.insert.await('INSERT IGNORE INTO `city_os_tablets` (`serial`, `owner`, `settings`) VALUES (?, ?, ?)', { serial, owner, json.encode(tablet.settings) })
    end

    cache[serial] = tablet

    return tablet
end

---@param tablet Tablet
---@param input unknown
---@return table saved settings
function tablets.saveSettings(tablet, input)
    tablet.settings = settings.sanitize(input)
    MySQL.update('UPDATE `city_os_tablets` SET `settings` = ? WHERE `serial` = ?', { json.encode(tablet.settings), tablet.serial })

    return tablet.settings
end

---@param tablet Tablet
---@param code? string four digits, or nil to remove the code
function tablets.setCode(tablet, code)
    tablet.codeHash = code and GetPasswordHash(code) or nil
    MySQL.update('UPDATE `city_os_tablets` SET `code_hash` = ? WHERE `serial` = ?', { tablet.codeHash, tablet.serial })
end

---@param tablet Tablet
---@param code string
---@return boolean
function tablets.checkCode(tablet, code)
    return tablet.codeHash ~= nil and VerifyPasswordHash(code, tablet.codeHash)
end

---@param citizenid string
---@return table<string, true>
function tablets.loadUnlocks(citizenid)
    Citizen.Await(ready)

    local unlocks = {}

    for _, row in ipairs(MySQL.query.await('SELECT `unlock_key` FROM `city_os_unlocks` WHERE `citizenid` = ?', { citizenid }) or {}) do
        unlocks[row.unlock_key] = true
    end

    return unlocks
end

---@param citizenid string
---@param key string
---@param unlocked boolean
function tablets.setUnlock(citizenid, key, unlocked)
    if unlocked then
        MySQL.insert('INSERT IGNORE INTO `city_os_unlocks` (`citizenid`, `unlock_key`) VALUES (?, ?)', { citizenid, key })
    else
        MySQL.update('DELETE FROM `city_os_unlocks` WHERE `citizenid` = ? AND `unlock_key` = ?', { citizenid, key })
    end
end

return tablets
