local schema = {}

-- System accounts: where new money comes from and where spent money goes (PROMPT_ECONOMIA_FIVEM.md 4)
schema.SYSTEM_ACCOUNTS = { 'WORLD_MINT', 'WORLD_SINK', 'GOV_TREASURY', 'BANK_RESERVE' }

function schema.create()
    -- unique_key = '<type>:<owner>' keeps one personal and one cash account per character.
    -- The CHECK is the database's last line of defence: a player balance can never go below 0 or above the cap.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `economy_accounts` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `unique_key` VARCHAR(80) NOT NULL,
            `number` CHAR(8) NULL,
            `type` ENUM('personal', 'cash', 'savings', 'shared', 'job', 'system') NOT NULL,
            `owner` VARCHAR(50) NULL,
            `label` VARCHAR(48) NOT NULL,
            `balance` BIGINT NOT NULL DEFAULT 0,
            `frozen` ENUM('debt', 'fraud', 'admin') NULL,
            `fingerprint_at` TIMESTAMP NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_key` (`unique_key`),
            UNIQUE KEY `number` (`number`),
            KEY `owner` (`owner`),
            CONSTRAINT `balance_range` CHECK (`type` = 'system' OR (`balance` >= 0 AND `balance` <= 1000000000))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Savings goals (BANCO_DESIGN.md 3.1), added after the first version of the table
    MySQL.query.await('ALTER TABLE `economy_accounts` ADD COLUMN IF NOT EXISTS `goal_amount` BIGINT NULL')
    MySQL.query.await('ALTER TABLE `economy_accounts` ADD COLUMN IF NOT EXISTS `goal_date` INT NULL')

    -- Append-only: rows are never updated or deleted, corrections are new rows
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `economy_ledger` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `tx_id` CHAR(16) NOT NULL,
            `account_id` INT UNSIGNED NOT NULL,
            `delta` BIGINT NOT NULL,
            `balance_after` BIGINT NOT NULL,
            `reason` VARCHAR(48) NOT NULL,
            `source` VARCHAR(64) NOT NULL,
            `ref` VARCHAR(64) NULL,
            `meta` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `account_time` (`account_id`, `created_at`),
            KEY `tx_id` (`tx_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Request ids already handled, so a replayed request never pays twice
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `economy_requests` (
            `request_id` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `economy_flags` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NULL,
            `license` VARCHAR(80) NULL,
            `kind` VARCHAR(48) NOT NULL,
            `severity` TINYINT UNSIGNED NOT NULL,
            `context` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    for i = 1, #schema.SYSTEM_ACCOUNTS do
        local name = schema.SYSTEM_ACCOUNTS[i]

        MySQL.insert.await(
            'INSERT IGNORE INTO `economy_accounts` (`unique_key`, `type`, `label`) VALUES (?, ?, ?)',
            { ('system:%s'):format(name), 'system', name }
        )
    end
end

return schema
