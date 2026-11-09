-- People: search citizens and open a person's file.

local mdt = require 'server.mdt.core'
local records = require 'server.records'
local settings = require 'server.config'
local db = require 'server.db'

---@param row table players row
---@return table
local function brief(row)
    local charinfo = json.decode(row.charinfo or '{}') or {}

    return {
        citizenid = row.citizenid,
        name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or ''),
        birthdate = charinfo.birthdate,
        phone = charinfo.phone,
        online = exports.qbx_core:GetPlayerByCitizenId(row.citizenid) ~= nil,
    }
end

---The player in the city with exactly this server id (the number in the scoreboard), as a one-row list.
---@param value unknown
---@return table[]
local function byServerId(value)
    local id = math.tointeger(tonumber(value))
    local player = id and id > 0 and exports.qbx_core:GetPlayer(id)
    if not player then return {} end

    local data = player.PlayerData
    local row = brief({ citizenid = data.citizenid, charinfo = json.encode(data.charinfo) })
    row.id = id

    return { row }
end

mdt.register('searchPeople', function(_, data)
    if data.by == 'id' then return true, byServerId(data.q) end

    local like = mdt.like(data.q)
    if not like then return true, {} end

    local exact = type(data.q) == 'string' and data.q:match('^%s*(.-)%s*$') or ''

    -- A to Z by first name, then last name, so "João" lists every João in order
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo FROM players
        WHERE CONCAT(JSON_VALUE(charinfo, '$.firstname'), ' ', JSON_VALUE(charinfo, '$.lastname')) LIKE ?
            OR citizenid LIKE ? OR phone_number LIKE ? OR JSON_VALUE(metadata, '$.fingerprint') = ?
        ORDER BY JSON_VALUE(charinfo, '$.firstname'), JSON_VALUE(charinfo, '$.lastname') LIMIT ?
    ]], { like, like, like, exact, settings.searchLimit }) or {}

    local list = {}
    for i = 1, #rows do
        list[i] = brief(rows[i])

        local online = exports.qbx_core:GetPlayerByCitizenId(rows[i].citizenid)
        if online then list[i].id = online.PlayerData.source end
    end

    return true, list
end, { 'people', 'charge' })

---@param citizenid string
---@return table
local function recordList(citizenid)
    local rows = MySQL.query.await('SELECT id, kind, charges, months, fine, points, notes, officer, created FROM city_police_records WHERE citizenid = ? ORDER BY id DESC LIMIT 30', { citizenid }) or {}

    for _, row in ipairs(rows) do row.charges = db.list(row.charges) end

    return rows
end

mdt.register('person', function(_, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local person = citizenid and mdt.person(citizenid)
    if not person then return false, 'not_found' end

    local metadata = person.metadata or {}
    local now = os.time()

    local warrants = MySQL.query.await("SELECT id, reason, charges, issued_by, created, expires FROM city_police_warrants WHERE citizenid = ? AND status = 'active' AND expires > ? ORDER BY id DESC", { citizenid, now }) or {}
    for _, row in ipairs(warrants) do row.charges = db.list(row.charges) end

    local reports = MySQL.query.await('SELECT id, kind, title, created FROM city_police_reports WHERE people LIKE ? ORDER BY id DESC LIMIT 20', { ('%%"%s"%%'):format(citizenid) }) or {}
    local vehicles = MySQL.query.await('SELECT plate, vehicle, state FROM player_vehicles WHERE citizenid = ? LIMIT 30', { citizenid }) or {}
    local weapons = MySQL.query.await('SELECT serial, label, status FROM city_police_weapons WHERE owner_cid = ? ORDER BY created DESC LIMIT 30', { citizenid }) or {}

    return true, {
        citizenid = citizenid,
        name = person.name,
        birthdate = person.charinfo.birthdate,
        gender = person.charinfo.gender,
        nationality = person.charinfo.nationality,
        phone = person.charinfo.phone,
        job = person.job and person.job.label,
        online = person.source ~= nil,
        id = person.source,
        fingerprint = metadata.fingerprint,
        bloodtype = metadata.bloodtype,
        anklet = metadata.tracker == true,
        licences = metadata.licences or {},
        points = records.points(citizenid),
        photo = records.photo(citizenid),
        warrants = warrants,
        records = recordList(citizenid),
        reports = reports,
        vehicles = vehicles,
        weapons = weapons,
    }
end, 'people')
