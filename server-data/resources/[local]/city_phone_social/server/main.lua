-- Creates the tables; stories older than Config.StoryHours are deleted every hour
local common = require 'server.common'

local PURGE_MS = 3600000

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_social_accounts` (
            `citizenid` VARCHAR(50) NOT NULL,
            `username` VARCHAR(20) NOT NULL,
            `name` VARCHAR(30) NOT NULL,
            `bio` VARCHAR(150) NOT NULL DEFAULT '',
            `avatar` MEDIUMTEXT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`citizenid`),
            UNIQUE KEY `username` (`username`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_social_posts` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `kind` ENUM('post', 'story') NOT NULL DEFAULT 'post',
            `image` MEDIUMTEXT NOT NULL,
            `caption` VARCHAR(300) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `kind` (`kind`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_social_likes` (
            `post_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            PRIMARY KEY (`post_id`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_social_comments` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `post_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `text` VARCHAR(200) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `post_id` (`post_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_social_follows` (
            `follower` VARCHAR(50) NOT NULL,
            `followed` VARCHAR(50) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`follower`, `followed`),
            KEY `followed` (`followed`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    common.setReady()
end

local function purgeStories()
    local cutoff = os.time() - Config.StoryHours * 3600
    MySQL.update.await([[DELETE FROM `phone_social_posts` WHERE `kind` = 'story' AND `created_at` < ?]], { cutoff })
end

CreateThread(function()
    createTables()

    while true do
        purgeStories()
        Wait(PURGE_MS)
    end
end)
