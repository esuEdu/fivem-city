-- Bank product tables. Money itself lives in city_economy; these hold cards, members, loans, bills and staff.
local schema = {}

local ready = promise.new()

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `bank_profiles` (
        `citizenid` VARCHAR(50) NOT NULL,
        `score` INT NOT NULL,
        `week_start` INT NOT NULL DEFAULT 0,
        `week_gain` INT NOT NULL DEFAULT 0,
        `credit_used` BIGINT NOT NULL DEFAULT 0,
        `cycle_start` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_members` (
        `account_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `perms` VARCHAR(120) NOT NULL DEFAULT 'view',
        `daily_limit` BIGINT NOT NULL DEFAULT 0,
        `status` ENUM('pending', 'active') NOT NULL DEFAULT 'pending',
        `created_at` INT NOT NULL,
        PRIMARY KEY (`account_id`, `citizenid`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_cards` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `card_id` CHAR(16) NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        `holder` VARCHAR(50) NOT NULL,
        `holder_name` VARCHAR(80) NOT NULL,
        `last4` CHAR(4) NOT NULL,
        `pin_hash` CHAR(64) NOT NULL,
        `pin_salt` CHAR(16) NOT NULL,
        `pin_tries` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `status` ENUM('active', 'locked', 'blocked', 'replaced') NOT NULL DEFAULT 'active',
        `contactless` TINYINT(1) NOT NULL DEFAULT 0,
        `limits` LONGTEXT NOT NULL,
        `ceilings` LONGTEXT NULL,
        `pending` LONGTEXT NULL,
        `pending_at` INT NOT NULL DEFAULT 0,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `card_id` (`card_id`),
        KEY `holder` (`holder`),
        KEY `account_id` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_card_tx` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `card_id` CHAR(16) NOT NULL,
        `kind` ENUM('debit', 'credit', 'atm', 'contactless', 'deposit') NOT NULL,
        `amount` BIGINT NOT NULL,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `card_time` (`card_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_bills` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` ENUM('fine', 'service', 'card', 'loan', 'admin') NOT NULL,
        `label` VARCHAR(80) NOT NULL,
        `issuer` VARCHAR(80) NOT NULL,
        `amount` BIGINT NOT NULL,
        `paid` BIGINT NOT NULL DEFAULT 0,
        `minimum` BIGINT NOT NULL DEFAULT 0,
        `payees` LONGTEXT NOT NULL,
        `status` ENUM('pending', 'overdue', 'paid', 'cancelled') NOT NULL DEFAULT 'pending',
        `due_at` INT NOT NULL,
        `created_at` INT NOT NULL,
        `ref` VARCHAR(32) NULL,
        PRIMARY KEY (`id`),
        KEY `citizen_status` (`citizenid`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_loans` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        `amount` BIGINT NOT NULL,
        `rate` DECIMAL(5, 2) NOT NULL,
        `total` BIGINT NOT NULL,
        `installments` TINYINT UNSIGNED NOT NULL,
        `installment` BIGINT NOT NULL,
        `paid_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `paid_total` BIGINT NOT NULL DEFAULT 0,
        `status` ENUM('requested', 'active', 'paid', 'denied') NOT NULL,
        `reason` VARCHAR(120) NOT NULL DEFAULT '',
        `next_due` INT NOT NULL DEFAULT 0,
        `decided_by` VARCHAR(80) NOT NULL DEFAULT '',
        `decision` VARCHAR(120) NOT NULL DEFAULT '',
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `citizen_status` (`citizenid`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_scheduled` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `from_account` INT UNSIGNED NOT NULL,
        `to_account` INT UNSIGNED NOT NULL,
        `amount` BIGINT NOT NULL,
        `frequency` ENUM('daily', 'weekly', 'biweekly') NOT NULL,
        `next_run` INT NOT NULL,
        `status` ENUM('active', 'paused') NOT NULL DEFAULT 'active',
        `reference` VARCHAR(60) NOT NULL DEFAULT '',
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `next_run` (`status`, `next_run`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_pos` (
        `pos_id` CHAR(12) NOT NULL,
        `owner` VARCHAR(50) NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`pos_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_bankers` (
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `added_by` VARCHAR(80) NOT NULL,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `bank_audit` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `actor` VARCHAR(80) NOT NULL,
        `action` VARCHAR(48) NOT NULL,
        `target` VARCHAR(80) NOT NULL,
        `details` LONGTEXT NOT NULL,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],


    [[CREATE TABLE IF NOT EXISTS `bank_state` (
        `name` VARCHAR(48) NOT NULL,
        `value` INT NOT NULL,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function schema.create()
    for i = 1, #TABLES do MySQL.query.await(TABLES[i]) end

    ready:resolve()
end

function schema.wait()
    Citizen.Await(ready)
end

return schema
