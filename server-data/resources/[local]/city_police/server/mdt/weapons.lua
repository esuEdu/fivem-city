-- Weapons: every weapon bought in a shop is registered here by serial (city_inventory tells us), searchable in the MDT.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local settings = require 'server.config'

local STATUSES = { registered = true, seized = true, stolen = true }

-- city_inventory: a player bought a weapon in a shop
AddEventHandler('city_inventory:server:boughtWeapon', function(src, name, metadata, shopLabel)
    if GetInvokingResource() ~= 'city_inventory' or type(metadata) ~= 'table' or type(metadata.serial) ~= 'string' then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local item = exports.city_inventory:Items(name)

    MySQL.insert('INSERT IGNORE INTO city_police_weapons (serial, item, label, owner_cid, owner, shop, created) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        metadata.serial, name, item and item.label or name, player.PlayerData.citizenid, police.fullName(player), shopLabel, os.time(),
    })
end)

mdt.register('searchWeapons', function(_, data)
    local like = mdt.like(data.q)

    local rows = like and MySQL.query.await('SELECT serial, label, owner, owner_cid, status FROM city_police_weapons WHERE serial LIKE ? OR owner LIKE ? ORDER BY created DESC LIMIT ?', { like, like, settings.searchLimit })
        or MySQL.query.await("SELECT serial, label, owner, owner_cid, status FROM city_police_weapons WHERE status <> 'registered' ORDER BY created DESC LIMIT ?", { settings.searchLimit })

    return true, rows or {}
end, 'weapons')

mdt.register('weapon', function(_, data)
    local serial = type(data.serial) == 'string' and data.serial:sub(1, 40)
    if not serial then return false, 'invalid' end

    local row = MySQL.single.await('SELECT * FROM city_police_weapons WHERE serial = ?', { serial })
    if not row then return false, 'not_found' end

    -- Casings picked up and analyzed that came from this gun
    row.casings = MySQL.query.await("SELECT id, place, collected_by, collected_at FROM city_police_evidence WHERE kind = 'casing' AND analyzed_at IS NOT NULL AND result LIKE ? ORDER BY id DESC LIMIT 20", {
        ('%%"serial":"%s"%%'):format((serial:gsub('[%%_\\"]', ''))),
    }) or {}

    return true, row
end, 'weapons')

mdt.register('setWeaponStatus', function(src, data)
    local serial = type(data.serial) == 'string' and data.serial:sub(1, 40)
    if not serial or not STATUSES[data.status] then return false, 'invalid' end

    local notes = police.clean(data.notes, settings.text.line)
    local changed = MySQL.update.await('UPDATE city_police_weapons SET status = ?, notes = ? WHERE serial = ?', { data.status, notes ~= '' and ('%s — %s'):format(notes, police.name(src)) or nil, serial })

    return changed > 0, changed > 0 and nil or 'not_found'
end, 'weapons')

---Serials of the weapons registered to a character, as a set (city_prison keeps these, seizes the rest)
---@param citizenid string
---@return table<string, true>
exports('RegisteredWeapons', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end

    local serials = {}
    local rows = MySQL.query.await("SELECT serial FROM city_police_weapons WHERE owner_cid = ? AND status = 'registered'", { citizenid })

    for _, row in ipairs(rows or {}) do serials[row.serial] = true end

    return serials
end)
