-- Criminal records: totals from the penal code, saving an arrest or a fine, driving points.

local penal = require 'shared.penal'
local settings = require 'server.config'

local records = {}

local CRIMES = {}
for _, crime in ipairs(penal.crimes) do CRIMES[crime.id] = crime end

---@param id string
---@return table?
function records.crime(id)
    return CRIMES[id]
end

---Checks the charges the page sent ({ id, count } each) and adds them up from the penal code.
---@param list unknown
---@return { id: string, title: string, count: integer }[]? charges
---@return { months: integer, fine: integer, points: integer }? totals
function records.total(list)
    if type(list) ~= 'table' or #list < 1 or #list > settings.maxCharges then return end

    local charges, seen = {}, {}
    local months, fine, points = 0, 0, 0

    for _, entry in ipairs(list) do
        local crime = type(entry) == 'table' and CRIMES[entry.id]
        local count = type(entry) == 'table' and math.tointeger(entry.count) or nil

        if not crime or not count or count < 1 or count > settings.maxCount or seen[crime.id] then return end

        seen[crime.id] = true
        charges[#charges + 1] = { id = crime.id, title = crime.title, count = count }
        months = months + crime.months * count
        fine = fine + crime.fine * count
        points = points + crime.points * count
    end

    return charges, {
        months = math.min(months, settings.maxMonths),
        fine = math.min(fine, settings.maxFine),
        points = points,
    }
end

---@param data { citizenid: string, name: string, kind: string, charges: table, months: integer, fine: integer, points: integer, notes: string?, officer: string, officerCid: string, photo: string?, fingerprint: string? }
---@return integer id
function records.add(data)
    return MySQL.insert.await([[
        INSERT INTO city_police_records (citizenid, name, kind, charges, months, fine, points, notes, officer, officer_cid, photo, fingerprint, created)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.citizenid, data.name, data.kind, json.encode(data.charges), data.months, data.fine, data.points, data.notes,
        data.officer, data.officerCid, data.photo, data.fingerprint, os.time(),
    })
end

---Driving points in the last settings.pointsDays days.
---@param citizenid string
---@return integer
function records.points(citizenid)
    local since = os.time() - settings.pointsDays * 86400

    return MySQL.scalar.await('SELECT COALESCE(SUM(points), 0) FROM city_police_records WHERE citizenid = ? AND created >= ?', { citizenid, since }) or 0
end

---The last booking photo of a person, if any.
---@param citizenid string
---@return string?
function records.photo(citizenid)
    return MySQL.scalar.await('SELECT photo FROM city_police_records WHERE citizenid = ? AND photo IS NOT NULL ORDER BY id DESC LIMIT 1', { citizenid })
end

---Active warrants of a person become served (an arrest serves them).
---@param citizenid string
---@param officer string
function records.serveWarrants(citizenid, officer)
    MySQL.update.await("UPDATE city_police_warrants SET status = 'served', closed_by = ?, closed_at = ? WHERE citizenid = ? AND status = 'active'", { officer, os.time(), citizenid })
end

return records
