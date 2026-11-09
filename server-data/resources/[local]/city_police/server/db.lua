-- The police tables, created on start. Times are unix seconds (os.time()); lists are JSON.

local db = {}

local TABLES = {
    [[
        CREATE TABLE IF NOT EXISTS `city_police_officers` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `callsign` VARCHAR(10) NULL,
            `certs` VARCHAR(255) NOT NULL DEFAULT '[]',
            `minutes` INT UNSIGNED NOT NULL DEFAULT 0,
            `last_duty` INT UNSIGNED NULL,
            `hired_at` INT UNSIGNED NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_shifts` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `started` INT UNSIGNED NOT NULL,
            `ended` INT UNSIGNED NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`, `started`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_records` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `kind` VARCHAR(10) NOT NULL,
            `charges` TEXT NOT NULL,
            `months` INT UNSIGNED NOT NULL DEFAULT 0,
            `fine` INT UNSIGNED NOT NULL DEFAULT 0,
            `points` INT UNSIGNED NOT NULL DEFAULT 0,
            `notes` VARCHAR(255) NULL,
            `officer` VARCHAR(100) NOT NULL,
            `officer_cid` VARCHAR(50) NOT NULL,
            `photo` MEDIUMTEXT NULL,
            `fingerprint` VARCHAR(50) NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`, `created`),
            KEY `created` (`created`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_reports` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(16) NOT NULL,
            `title` VARCHAR(100) NOT NULL,
            `place` VARCHAR(100) NULL,
            `body` TEXT NOT NULL,
            `people` TEXT NOT NULL,
            `plates` VARCHAR(255) NOT NULL DEFAULT '[]',
            `evidence` VARCHAR(255) NOT NULL DEFAULT '[]',
            `author` VARCHAR(100) NOT NULL,
            `author_cid` VARCHAR(50) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            `updated` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `created` (`created`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_bolos` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(10) NOT NULL,
            `title` VARCHAR(100) NOT NULL,
            `description` TEXT NOT NULL,
            `plate` VARCHAR(8) NULL,
            `status` VARCHAR(10) NOT NULL DEFAULT 'active',
            `created_by` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            `expires` INT UNSIGNED NOT NULL,
            `closed_by` VARCHAR(100) NULL,
            `closed_at` INT UNSIGNED NULL,
            PRIMARY KEY (`id`),
            KEY `status` (`status`, `expires`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_warrants` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `reason` VARCHAR(255) NOT NULL,
            `charges` TEXT NOT NULL,
            `status` VARCHAR(10) NOT NULL DEFAULT 'active',
            `issued_by` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            `expires` INT UNSIGNED NOT NULL,
            `closed_by` VARCHAR(100) NULL,
            `closed_at` INT UNSIGNED NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `status` (`status`, `expires`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_plates` (
            `plate` VARCHAR(15) NOT NULL,
            `status` VARCHAR(10) NOT NULL,
            `reason` VARCHAR(255) NOT NULL,
            `by_name` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_weapons` (
            `serial` VARCHAR(40) NOT NULL,
            `item` VARCHAR(60) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `owner_cid` VARCHAR(50) NULL,
            `owner` VARCHAR(100) NULL,
            `shop` VARCHAR(100) NULL,
            `status` VARCHAR(12) NOT NULL DEFAULT 'registered',
            `notes` VARCHAR(255) NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`serial`),
            KEY `owner_cid` (`owner_cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_impounds` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(15) NOT NULL,
            `citizenid` VARCHAR(50) NULL,
            `model` VARCHAR(50) NULL,
            `reason` VARCHAR(255) NOT NULL,
            `fee` INT UNSIGNED NOT NULL DEFAULT 0,
            `hold_until` INT UNSIGNED NOT NULL,
            `officer` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            `released_at` INT UNSIGNED NULL,
            `released_by` VARCHAR(100) NULL,
            PRIMARY KEY (`id`),
            KEY `plate` (`plate`),
            KEY `open` (`released_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_evidence` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(12) NOT NULL,
            `place` VARCHAR(100) NULL,
            `result` TEXT NOT NULL,
            `collected_by` VARCHAR(100) NOT NULL,
            `collected_at` INT UNSIGNED NOT NULL,
            `analyzed_by` VARCHAR(100) NULL,
            `analyzed_at` INT UNSIGNED NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    -- Cases (the Reports table grown up): crime tags and attached photos; records point back to their case
    [[ ALTER TABLE `city_police_reports` ADD COLUMN IF NOT EXISTS `tags` VARCHAR(255) NOT NULL DEFAULT '[]' ]],
    [[ ALTER TABLE `city_police_reports` ADD COLUMN IF NOT EXISTS `photos` VARCHAR(255) NOT NULL DEFAULT '[]' ]],
    [[ ALTER TABLE `city_police_reports` MODIFY `people` MEDIUMTEXT NOT NULL ]],
    [[ ALTER TABLE `city_police_records` ADD COLUMN IF NOT EXISTS `report_id` INT UNSIGNED NULL ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_case_photos` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `report_id` INT UNSIGNED NULL,
            `officer_cid` VARCHAR(50) NOT NULL,
            `data` MEDIUMTEXT NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `report_id` (`report_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    -- Uniforms made in game, and each officer's own clothes kept while they wear one
    [[
        CREATE TABLE IF NOT EXISTS `city_police_uniforms` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(40) NOT NULL,
            `sex` VARCHAR(6) NOT NULL,
            `components` TEXT NOT NULL,
            `props` TEXT NOT NULL,
            `created_by` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_wardrobe` (
            `citizenid` VARCHAR(50) NOT NULL,
            `components` TEXT NOT NULL,
            `props` TEXT NOT NULL,
            `saved` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `city_police_notices` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `text` VARCHAR(500) NOT NULL,
            `author` VARCHAR(100) NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

local ready = promise.new()

function db.init()
    for i = 1, #TABLES do
        MySQL.query.await(TABLES[i])
    end

    ready:resolve(true)
end

---Waits until the tables exist (for code that runs at start).
function db.wait()
    Citizen.Await(ready)
end

---@param value unknown
---@return table
function db.list(value)
    if type(value) ~= 'string' or value == '' then return {} end

    local ok, decoded = pcall(json.decode, value)

    return ok and type(decoded) == 'table' and decoded or {}
end

return db
