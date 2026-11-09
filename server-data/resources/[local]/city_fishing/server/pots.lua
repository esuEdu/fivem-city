-- Crab pots: placed in water with a bait, saved in city_fishing_pots, ready after a while. Anyone can pull any pot:
-- the owner gets the catch and the pot back; someone else takes both and the owner hears about it on the phone.
local settings = require 'server.config'
local fish = require 'server.fish'
local regions = require 'server.regions'
local levels = require 'shared.levels'
local gear = require 'shared.gear'
local profiles = require 'server.profiles'
local util = require 'server.util'

local JUNK = { 'junk_can', 'junk_boot', 'junk_newspaper' }
local MIN_GAP = 3.0

---@type table<integer, table>
local pots = {}

---@param pot table
---@return table what clients need
local function public(pot)
    return { id = pot.id, coords = pot.coords, owner = pot.ownerName }
end

local function load()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_fishing_pots` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `owner_name` VARCHAR(80) NOT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `region` VARCHAR(16) NOT NULL,
            `bait` VARCHAR(50) NOT NULL,
            `placed_at` INT NOT NULL,
            INDEX (`citizenid`)
        )
    ]])

    local oldest = os.time() - settings.pots.expireHours * 3600
    MySQL.query.await('DELETE FROM `city_fishing_pots` WHERE `placed_at` < ?', { oldest })

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `city_fishing_pots`') or {}) do
        pots[row.id] = {
            id = row.id,
            citizenid = row.citizenid,
            ownerName = row.owner_name,
            coords = vector3(row.x, row.y, row.z),
            region = row.region,
            bait = row.bait,
            placedAt = row.placed_at,
        }
    end
end

---@param id integer
local function remove(id)
    pots[id] = nil
    MySQL.query('DELETE FROM `city_fishing_pots` WHERE `id` = ?', { id })
    TriggerClientEvent('city_fishing:client:potRemoved', -1, id)
end

---@param citizenid string
---@return integer
local function ownedBy(citizenid)
    local count = 0
    for _, pot in pairs(pots) do
        if pot.citizenid == citizenid then count = count + 1 end
    end

    return count
end

---Seconds until the pot is ready, for its owner's skills.
---@param pot table
---@return integer
local function secondsLeft(pot)
    local skills = profiles.get(pot.citizenid).skills
    local total = settings.pots.minutes * 60 * (1 - levels.value(skills, 'speed'))

    return math.max(0, math.floor(pot.placedAt + total - os.time()))
end

---What a ready pot holds (research section 11).
---@param pot table
---@return string item
---@return integer stars
local function rollCatch(pot)
    local skills = profiles.get(pot.citizenid).skills
    local list = fish.crustaceans[regions.water(pot.region)]
    local mariner = levels.value(skills, 'mariner') > 0
    local stars = pot.bait == 'bait_deluxe' and 2 or 1

    if mariner then return list[math.random(#list)].name, stars end

    if math.random() < settings.pots.junk - levels.value(skills, 'junk') then
        return JUNK[math.random(#JUNK)], 1
    end

    for _, entry in ipairs(list) do
        local chance = entry.chance
        if math.random() < chance then return entry.name, stars end
    end

    return JUNK[math.random(#JUNK)], 1
end

lib.callback.register('city_fishing:pots', function()
    local list = {}
    for _, pot in pairs(pots) do list[#list + 1] = public(pot) end

    return list
end)

lib.callback.register('city_fishing:placePot', function(source, coordsData)
    local src = source
    if not Config.Features.pots then return false end
    local player, citizenid = util.player(src)
    if not player then return false end

    local x, y, z = type(coordsData) == 'table' and tonumber(coordsData.x), type(coordsData) == 'table' and tonumber(coordsData.y), type(coordsData) == 'table' and tonumber(coordsData.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return false, 'invalid' end

    local coords = vector3(x, y, z)
    if not util.near(src, coords, settings.pots.placeRange) then return false, 'too_far' end
    if exports.city_inventory:GetItemCount(src, gear.pot.item) < 1 then return false, 'invalid' end

    local profile = profiles.get(citizenid)
    if ownedBy(citizenid) >= settings.pots.max + levels.value(profile.skills, 'pots') then return false, 'pot_limit' end

    for _, pot in pairs(pots) do
        if #(pot.coords - coords) < MIN_GAP then return false, 'pot_too_close' end
    end

    -- Any bait; the deluxe one goes first because it gives better crustaceans
    local bait
    for _, name in ipairs({ 'bait_deluxe', 'bait_worm', 'bait_wild', 'bait_magnet', 'bait_challenge' }) do
        if exports.city_inventory:GetItemCount(src, name) > 0 then
            bait = name
            break
        end
    end
    if not bait then return false, 'pot_no_bait' end

    if not exports.city_inventory:RemoveItem(src, gear.pot.item, 1) then return false, 'invalid' end
    if math.random() >= levels.value(profile.skills, 'saver') then exports.city_inventory:RemoveItem(src, bait, 1) end

    local region = regions.at(x, y)
    local pot = {
        citizenid = citizenid,
        ownerName = util.name(src),
        coords = coords,
        region = region,
        bait = bait,
        placedAt = os.time(),
    }

    pot.id = MySQL.insert.await('INSERT INTO `city_fishing_pots` (`citizenid`, `owner_name`, `x`, `y`, `z`, `region`, `bait`, `placed_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        citizenid, pot.ownerName, x, y, z, region, bait, pot.placedAt,
    })

    if not pot.id then
        exports.city_inventory:AddItem(src, gear.pot.item, 1)
        return false, 'invalid'
    end

    pots[pot.id] = pot
    TriggerClientEvent('city_fishing:client:potAdded', -1, public(pot))

    return true
end)

lib.callback.register('city_fishing:pullPot', function(source, id)
    local src = source
    if not Config.Features.pots then return false end
    local player, citizenid = util.player(src)
    if not player then return false end

    local pot = type(id) == 'number' and pots[id]
    if not pot then return false, 'invalid' end
    if not util.near(src, pot.coords, settings.pots.pullRange) then return false, 'too_far' end
    if not exports.city_inventory:CanCarryItem(src, gear.pot.item, 1) then return false, 'inventory_full' end

    local mine = pot.citizenid == citizenid
    local ready = secondsLeft(pot) == 0
    local item, stars

    if ready then
        item, stars = rollCatch(pot)
        local metadata = fish.byName[item] and { quality = stars } or nil
        if not exports.city_inventory:CanCarryItem(src, item, 1, metadata) then return false, 'inventory_full' end

        exports.city_inventory:AddItem(src, item, 1, metadata)
        profiles.addXp(profiles.get(citizenid), settings.pots.xp)
    end

    remove(pot.id)
    exports.city_inventory:AddItem(src, gear.pot.item, 1)

    if not mine then
        lib.print.info(('Crab pot %s of %s was pulled by %s (%s)'):format(pot.id, pot.citizenid, citizenid, src))

        local owner = exports.qbx_core:GetPlayerByCitizenId(pot.citizenid)
        if owner and GetResourceState('city_phone') == 'started' then
            exports.city_phone:Notify(owner.PlayerData.source, { title = locale('pot_stolen_title'), text = locale('pot_stolen_text') })
        end
    end

    return true, { ready = ready, label = item and (fish.byName[item] and fish.byName[item].label or item) or nil, mine = mine }
end)

-- The app's Pots tab: this character's pots, time left and where
lib.callback.register('city_fishing:app:pots', function(source)
    if not Config.Features.pots then return false end

    local _, citizenid = util.player(source)
    if not citizenid then return false end

    local list = {}

    for _, pot in pairs(pots) do
        if pot.citizenid == citizenid then
            list[#list + 1] = { id = pot.id, x = pot.coords.x, y = pot.coords.y, secondsLeft = secondsLeft(pot), placedAt = pot.placedAt }
        end
    end

    table.sort(list, function(a, b) return a.placedAt < b.placedAt end)

    return true, list
end)

MySQL.ready(function()
    load()

    -- Pots left too long rot away
    while true do
        Wait(600000)

        local oldest = os.time() - settings.pots.expireHours * 3600
        for id, pot in pairs(pots) do
            if pot.placedAt < oldest then remove(id) end
        end
    end
end)
