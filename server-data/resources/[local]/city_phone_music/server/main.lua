-- Creates the tables
local common = require 'server.common'

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_music_tracks` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `kind` ENUM('youtube', 'url') NOT NULL,
            `ref` VARCHAR(500) NOT NULL,
            `title` VARCHAR(100) NOT NULL,
            `artist` VARCHAR(100) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_music_playlists` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(40) NOT NULL,
            `created_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_music_playlist_tracks` (
            `playlist_id` INT NOT NULL,
            `track_id` INT NOT NULL,
            `position` INT NOT NULL,
            PRIMARY KEY (`playlist_id`, `track_id`),
            KEY `track_id` (`track_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    common.setReady()
end)
