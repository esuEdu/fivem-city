-- Evidence tab: bags the officer carries, analyzing them at a station lab, the lab results, scanning a fingerprint;
-- and the Cameras tab.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local roster = require 'server.roster'
local db = require 'server.db'

---@param src integer
---@return boolean
local function atLab(src)
    for _, station in ipairs(Config.Stations) do
        if station.lab and police.near(src, station.lab, Config.Ranges.place + 2.0) then return true end
    end

    return false
end

---Finds a character by fingerprint id: online first, then the players table.
---@param fingerprint string
---@return table? { citizenid, name }
local function byFingerprint(fingerprint)
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData.metadata.fingerprint == fingerprint then
            return { citizenid = player.PlayerData.citizenid, name = police.fullName(player) }
        end
    end

    local row = MySQL.single.await("SELECT citizenid, charinfo FROM players WHERE JSON_VALUE(metadata, '$.fingerprint') = ?", { fingerprint })
    if not row then return end

    local charinfo = json.decode(row.charinfo or '{}') or {}

    return { citizenid = row.citizenid, name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '') }
end

---What the lab tells about one piece of evidence.
---@param row table city_police_evidence row
---@return table
local function findings(row)
    local raw = db.list(row.result)
    local out = { id = row.id, kind = row.kind, place = row.place, collectedBy = row.collected_by, collectedAt = row.collected_at, analyzedBy = row.analyzed_by, analyzedAt = row.analyzed_at }

    if not row.analyzed_at then return out end

    if row.kind == 'casing' then
        out.weapon = raw.label
        out.serial = raw.serial
        local weapon = raw.serial and MySQL.single.await('SELECT owner, owner_cid, status FROM city_police_weapons WHERE serial = ?', { raw.serial })
        out.owner = weapon and weapon.owner
        out.ownerCid = weapon and weapon.owner_cid
    elseif row.kind == 'blood' then
        local person = raw.citizenid and mdt.person(raw.citizenid)
        out.bloodtype = raw.bloodtype
        out.owner = person and person.name
        out.ownerCid = raw.citizenid
    elseif row.kind == 'fingerprint' then
        local person = raw.fingerprint and byFingerprint(raw.fingerprint)
        out.fingerprint = raw.fingerprint
        out.owner = person and person.name
        out.ownerCid = person and person.citizenid
    end

    return out
end

mdt.register('evidence', function(src)
    local bags = {}

    for slot, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        if item.name == 'filled_evidence_bag' and item.metadata and math.tointeger(item.metadata.evidenceId) then
            bags[#bags + 1] = { slot = slot, id = item.metadata.evidenceId, kind = item.metadata.kind, label = item.metadata.label }
        end
    end

    local results = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM city_police_evidence WHERE analyzed_at IS NOT NULL ORDER BY analyzed_at DESC LIMIT 30') or {}) do
        results[#results + 1] = findings(row)
    end

    return true, { bags = bags, results = results, atLab = atLab(src), forensics = roster.hasCert(src, 'forensics') }
end)

mdt.register('analyze', function(src, data)
    if not roster.hasCert(src, 'forensics') then return false, 'no_cert' end
    if not atLab(src) then return false, 'not_at_lab' end

    local slot = math.tointeger(data.slot)
    local item = slot and exports.city_inventory:GetSlot(src, slot)
    local id = item and item.name == 'filled_evidence_bag' and item.metadata and math.tointeger(item.metadata.evidenceId)
    if not id then return false, 'invalid' end

    local row = MySQL.single.await('SELECT * FROM city_police_evidence WHERE id = ?', { id })
    if not row then return false, 'not_found' end

    if not row.analyzed_at then
        MySQL.update.await('UPDATE city_police_evidence SET analyzed_by = ?, analyzed_at = ? WHERE id = ?', { police.name(src), os.time(), id })
        row.analyzed_by, row.analyzed_at = police.name(src), os.time()
    end

    return true, findings(row)
end, 'evidence')

mdt.register('evidenceItem', function(_, data)
    local id = mdt.id(data.id)
    local row = id and MySQL.single.await('SELECT * FROM city_police_evidence WHERE id = ?', { id })
    if not row then return false, 'not_found' end

    return true, findings(row)
end, 'evidence')

-- The scanner at the lab: the person standing next to the officer
mdt.register('scanFingerprint', function(src, data)
    if not atLab(src) then return false, 'not_at_lab' end

    local target = police.reach(src, data.target)
    local player = target and exports.qbx_core:GetPlayer(target)
    if not player then return false, 'too_far' end

    return true, { citizenid = player.PlayerData.citizenid, name = police.fullName(player), fingerprint = player.PlayerData.metadata.fingerprint }
end, 'evidence')

mdt.register('viewCamera', function(_, data)
    local index = math.tointeger(data.index)
    if not index or not Config.Cameras[index] then return false, 'invalid' end

    return true, index
end, 'cameras')
