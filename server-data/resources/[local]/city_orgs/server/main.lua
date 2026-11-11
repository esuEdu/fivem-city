-- Creates the faction gangs in qbx_core, registers each faction's vault stash and the tables, and loads the farm
-- counters. Staff puts players in a faction from the Staff app (set gang); the faction's own leader hires in the app.
lib.locale()

local orgs = require 'server.orgs'

MySQL.query.await([[CREATE TABLE IF NOT EXISTS `city_orgs_farm` (
    `gang` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `item` VARCHAR(100) NOT NULL,
    `day` DATE NOT NULL,
    `deposited` INT NOT NULL DEFAULT 0,
    `withdrawn` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`gang`, `citizenid`, `item`, `day`)
)]])

MySQL.query.await([[CREATE TABLE IF NOT EXISTS `city_orgs_goals` (
    `gang` VARCHAR(50) NOT NULL,
    `period` VARCHAR(10) NOT NULL,
    `mode` VARCHAR(10) NOT NULL,
    `amount` INT NULL,
    `items` TEXT NOT NULL,
    PRIMARY KEY (`gang`, `period`)
)]])

MySQL.query.await([[CREATE TABLE IF NOT EXISTS `city_orgs_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `gang` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `details` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang`, `id`)
)]])

local function createGangs()
    local gangs = {}

    for gang, faction in pairs(orgs.factions) do
        local grades = {}

        for level, grade in pairs(Config.Grades) do
            grades[level] = { name = grade.name, isboss = grade.isboss, bankAuth = grade.bankAuth }
        end

        gangs[gang] = { label = faction.label, grades = grades }
    end

    local success, message = exports.qbx_core:CreateGangs(gangs, false)

    if not success then
        lib.print.error(('city_orgs: creating the faction gangs failed: %s'):format(message))
    end
end

local function registerStashes()
    for gang, faction in pairs(orgs.factions) do
        exports.city_inventory:RegisterStash(('org:%s'):format(gang), ('%s Vault'):format(faction.label),
            faction.stash.slots, faction.stash.maxWeight, nil, { [gang] = 0 },
            vec3(faction.vault.x, faction.vault.y, faction.vault.z))
    end
end

createGangs()
registerStashes()

-- Both forget what other resources registered when they restart
AddEventHandler('onResourceStart', function(resource)
    if resource == 'qbx_core' then createGangs() end
    if resource == 'city_inventory' then registerStashes() end
end)

require 'server.farm'
