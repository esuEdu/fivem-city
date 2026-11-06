-- The staff log and warnings tables: every staff action is written here, with who did it and to whom.

local log = {}

function log.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_staff_log` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `staff_name` VARCHAR(100) NOT NULL,
            `staff_license` VARCHAR(60) NULL,
            `action` VARCHAR(32) NOT NULL,
            `target_name` VARCHAR(100) NULL,
            `target_citizenid` VARCHAR(50) NULL,
            `details` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `target_citizenid` (`target_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_staff_warnings` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `license` VARCHAR(60) NULL,
            `reason` VARCHAR(255) NOT NULL,
            `staff_name` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

---Who a player is: "Firstname Lastname (account name)", their license and citizenid.
---@param src integer
---@return { name: string, license: string?, citizenid: string? }
function log.who(src)
    if src == 0 then return { name = 'Console' } end

    local player = exports.qbx_core:GetPlayer(src)
    local charinfo = player and player.PlayerData.charinfo
    local account = GetPlayerName(src) or tostring(src)

    return {
        name = charinfo and ('%s %s (%s)'):format(charinfo.firstname, charinfo.lastname, account) or account,
        license = GetPlayerIdentifierByType(tostring(src), 'license2') or GetPlayerIdentifierByType(tostring(src), 'license'),
        citizenid = player and player.PlayerData.citizenid,
    }
end

---Writes one staff action. target: a server id, or { name, citizenid } for someone offline.
---@param src integer staff member
---@param action string
---@param target? integer | { name: string?, citizenid: string? }
---@param details? string
function log.add(src, action, target, details)
    local staff = log.who(src)
    local who = type(target) == 'number' and log.who(target) or target or {}

    lib.print.info(('%s: %s %s %s'):format(staff.name, action, who.name or '', details or ''))

    MySQL.insert('INSERT INTO `city_staff_log` (`staff_name`, `staff_license`, `action`, `target_name`, `target_citizenid`, `details`) VALUES (?, ?, ?, ?, ?, ?)', {
        staff.name:sub(1, 100),
        staff.license,
        action,
        who.name and who.name:sub(1, 100),
        who.citizenid,
        details and details:sub(1, 255),
    })
end

---The newest entries. Yields.
---@param limit integer
---@return table[]
function log.recent(limit)
    return MySQL.query.await('SELECT `id`, `staff_name`, `action`, `target_name`, `details`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `city_staff_log` ORDER BY `id` DESC LIMIT ?', { limit }) or {}
end

return log
