-- Creates the tables
local common = require 'server.common'

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_dating_profiles` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(30) NOT NULL,
            `bio` VARCHAR(300) NOT NULL DEFAULT '',
            `age` INT NULL,
            `gender` TINYINT NOT NULL DEFAULT 0,
            `interest` ENUM('men', 'women', 'everyone') NOT NULL DEFAULT 'everyone',
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_dating_photos` (
            `profile_id` INT NOT NULL,
            `slot` TINYINT NOT NULL,
            `image` MEDIUMTEXT NOT NULL,
            PRIMARY KEY (`profile_id`, `slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_dating_swipes` (
            `from_id` INT NOT NULL,
            `to_id` INT NOT NULL,
            `liked` TINYINT(1) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`from_id`, `to_id`),
            KEY `to_id` (`to_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_dating_matches` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `a` INT NOT NULL,
            `b` INT NOT NULL,
            `created_at` INT NOT NULL,
            `last_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `pair` (`a`, `b`),
            KEY `b` (`b`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_dating_messages` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `match_id` INT NOT NULL,
            `sender` INT NOT NULL,
            `text` VARCHAR(500) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `match_id` (`match_id`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    common.setReady()
end)
