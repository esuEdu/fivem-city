-- The station armory: free service gear in tiers, one tier per rank (server/config.lua armory). An officer unlocks
-- the tiers in order up to their own rank (saved in city_police_armory) and takes items from the unlocked tiers at or
-- below their rank, up to a carry limit. Weapons taken here are registered to the officer by serial.

local police = require 'server.police'
local db = require 'server.db'
local settings = require 'server.config'

local weaponData = require '@city_inventory.data.weapons'

local RANGE = Config.Ranges.place + 1.0
local SERIAL = 'POL'

local armory = settings.armory
local LAST_TIER = #armory.tiers - 1

---@class ArmoryEntry
---@field name string
---@field label string
---@field kind 'weapon' | 'ammo' | 'gear'
---@field count integer
---@field max integer
---@field ammo? string the weapon's ammo item

---@type table<integer, ArmoryEntry[]> tier -> entries
local tiers = {}
---@type table<string, integer> item -> tier it belongs to
local tierOf = {}
---@type table<string, integer> citizenid -> highest unlocked tier
local unlocked = {}
---@type table<integer, integer> src -> GetGameTimer of the last take
local lastTake = {}

---@param name string
---@return string?
local function labelOf(name)
    local item = exports.city_inventory:Items(name)

    return item and item.label
end

---@param name string lowercase item name
---@return table? data.weapons entry
local function weaponOf(name)
    return weaponData.Weapons[name:upper()]
end

---@param entry { name: string, count?: integer, max?: integer }
---@return ArmoryEntry?
local function build(entry)
    local name = entry.name:lower()
    local label = labelOf(name)

    if not label then
        lib.print.warn(('armory item %s does not exist in city_inventory'):format(name))
        return
    end

    local weapon = weaponOf(name)
    local ammo = weapon and type(weapon.ammoname) == 'string' and weapon.ammoname:lower() or nil
    if ammo and (ammo == name or not labelOf(ammo)) then ammo = nil end

    return {
        name = name,
        label = label,
        kind = weapon and 'weapon' or 'gear',
        count = math.max(1, math.tointeger(entry.count) or 1),
        max = math.max(1, math.tointeger(entry.max) or 1),
        ammo = ammo,
    }
end

CreateThread(function()
    while GetResourceState('city_inventory') ~= 'started' do Wait(200) end

    for index, list in ipairs(armory.tiers) do
        local tier = index - 1
        tiers[tier] = {}

        for _, entry in ipairs(list) do
            local built = build(entry)
            if built and not tierOf[built.name] then
                tiers[tier][#tiers[tier] + 1] = built
                tierOf[built.name] = tier
            end
        end
    end

    -- Every weapon no tier lists goes to the last one, sorted by label
    local rest = {}

    for key in pairs(weaponData.Weapons) do
        local name = key:lower()
        if not tierOf[name] then
            local built = build({ name = name })
            if built then rest[#rest + 1] = built end
        end
    end

    table.sort(rest, function(a, b) return a.label < b.label end)

    for _, built in ipairs(rest) do
        tiers[LAST_TIER][#tiers[LAST_TIER] + 1] = built
        tierOf[built.name] = LAST_TIER
    end
end)

---@param citizenid string
---@return integer
local function unlockedTier(citizenid)
    if unlocked[citizenid] then return unlocked[citizenid] end

    db.wait()
    local tier = MySQL.scalar.await('SELECT tier FROM city_police_armory WHERE citizenid = ?', { citizenid })
    unlocked[citizenid] = math.min(math.tointeger(tier) or 0, LAST_TIER)

    return unlocked[citizenid]
end

---@param src integer
---@return boolean
local function atArmory(src)
    for _, station in ipairs(Config.Stations) do
        if station.armory and police.near(src, station.armory.xyz, RANGE) then return true end
    end

    return false
end

---The officer at an armory, on duty: their citizenid and rank, or nil.
---@param src integer
---@return string?, integer?
local function officerAt(src)
    if not police.onDuty(src) or not atArmory(src) then return end

    local citizenid = police.citizenid(src)
    if not citizenid then return end

    return citizenid, police.grade(src)
end

---What the officer may take now: items of the tiers unlocked and at or below their rank, plus the ammo of those weapons.
---@param citizenid string
---@param grade integer
---@return table<string, ArmoryEntry>
local function available(citizenid, grade)
    local top = math.min(unlockedTier(citizenid), grade, LAST_TIER)
    local list = {}

    for tier = 0, top do
        for _, entry in ipairs(tiers[tier] or {}) do
            list[entry.name] = entry

            if entry.ammo and not list[entry.ammo] then
                list[entry.ammo] = {
                    name = entry.ammo,
                    label = labelOf(entry.ammo) or entry.ammo,
                    kind = 'ammo',
                    count = armory.ammo.count,
                    max = armory.ammo.max,
                }
            end
        end
    end

    return list
end

---Everything the page shows.
---@param src integer
---@param citizenid string
---@param grade integer
---@return table
local function view(src, citizenid, grade)
    local job = exports.qbx_core:GetJob(Config.Job)
    local rankNames = {}

    for level, data in pairs(job and job.grades or {}) do rankNames[level] = data.name end

    local tree = {}

    for tier = 0, LAST_TIER do
        local items = {}

        for _, entry in ipairs(tiers[tier] or {}) do
            items[#items + 1] = { name = entry.name, label = entry.label, kind = entry.kind }
        end

        tree[#tree + 1] = { tier = tier, rank = rankNames[tier] or tostring(tier), items = items }
    end

    local stock = {}

    for _, entry in pairs(available(citizenid, grade)) do
        stock[#stock + 1] = {
            name = entry.name,
            label = entry.label,
            kind = entry.kind,
            count = entry.count,
            max = entry.max,
            have = exports.city_inventory:GetItemCount(src, entry.name),
        }
    end

    table.sort(stock, function(a, b)
        if a.kind ~= b.kind then return a.kind > b.kind end
        return a.label < b.label
    end)

    return {
        grade = grade,
        rank = rankNames[grade] or tostring(grade),
        unlocked = unlockedTier(citizenid),
        lastTier = LAST_TIER,
        tree = tree,
        stock = stock,
    }
end

lib.callback.register('city_police:armory:open', function(source)
    local src = source
    local citizenid, grade = officerAt(src)
    if not citizenid then return end

    return view(src, citizenid, grade)
end)

lib.callback.register('city_police:armory:unlock', function(source, tier)
    local src = source
    local citizenid, grade = officerAt(src)
    if not citizenid then return false, 'too_far' end

    tier = math.tointeger(tier)
    if not tier then return false, 'failed' end

    local current = unlockedTier(citizenid)

    -- One tier at a time, in order, never above the officer's own rank
    if tier ~= current + 1 or tier > LAST_TIER or tier > grade then
        police.warn(src, ('tried to unlock armory tier %s (unlocked %d, rank %d)'):format(tier, current, grade))
        return false, 'armory_locked'
    end

    MySQL.prepare.await('INSERT INTO city_police_armory (citizenid, tier, updated) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE tier = VALUES(tier), updated = VALUES(updated)', {
        citizenid, tier, os.time(),
    })
    unlocked[citizenid] = tier

    return true, view(src, citizenid, grade)
end)

lib.callback.register('city_police:armory:take', function(source, name)
    local src = source
    local citizenid, grade = officerAt(src)
    if not citizenid then return false, 'too_far' end
    if type(name) ~= 'string' or #name > 60 then return false, 'failed' end

    local now = GetGameTimer()
    if lastTake[src] and now - lastTake[src] < armory.takeCooldownMs then return false, 'slow_down' end
    lastTake[src] = now

    local entry = available(citizenid, grade)[name]
    if not entry then
        police.warn(src, ('tried to take %s from the armory without it unlocked'):format(name))
        return false, 'armory_locked'
    end

    local have = exports.city_inventory:GetItemCount(src, entry.name)
    local count = math.min(entry.count, entry.max - have)
    if count < 1 then return false, 'armory_max' end

    local metadata

    if entry.kind == 'weapon' then
        local player = exports.qbx_core:GetPlayer(src)
        if not player then return false, 'failed' end

        metadata = {
            registered = police.fullName(player),
            serial = ('%s%s'):format(SERIAL, lib.string.random('111AAA111AA')),
        }
    end

    if not exports.city_inventory:CanCarryItem(src, entry.name, count, metadata) then return false, 'inventory_full' end
    if not exports.city_inventory:AddItem(src, entry.name, count, metadata) then return false, 'inventory_full' end

    if metadata then
        MySQL.insert('INSERT IGNORE INTO city_police_weapons (serial, item, label, owner_cid, owner, shop, created) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            metadata.serial, entry.name, entry.label, citizenid, metadata.registered, locale('armory'), os.time(),
        })
    end

    return true, view(src, citizenid, grade)
end)

AddEventHandler('playerDropped', function()
    lastTake[source] = nil
end)
