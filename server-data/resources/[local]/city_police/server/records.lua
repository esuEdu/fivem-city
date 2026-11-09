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

---@param data { citizenid: string, name: string, kind: string, charges: table, months: integer, fine: integer, points: integer, notes: string?, officer: string, officerCid: string, photo: string?, fingerprint: string?, caseId: integer? }
---@return integer id
function records.add(data)
    return MySQL.insert.await([[
        INSERT INTO city_police_records (citizenid, name, kind, charges, months, fine, points, notes, officer, officer_cid, photo, fingerprint, report_id, created)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.citizenid, data.name, data.kind, json.encode(data.charges), data.months, data.fine, data.points, data.notes,
        data.officer, data.officerCid, data.photo, data.fingerprint, data.caseId, os.time(),
    })
end

---Driving points in the last settings.pointsDays days.
---@param citizenid string
---@return integer
function records.points(citizenid)
    local since = os.time() - settings.pointsDays * 86400

    -- SUM comes back from MySQL as a DECIMAL string
    return tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(points), 0) FROM city_police_records WHERE citizenid = ? AND created >= ?', { citizenid, since })) or 0
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

---The sentence after a reduction the officer chose: a percent off (first arrest, a lawyer) or a set number of months.
---@param months integer from the penal code
---@param reduction unknown { kind = 'percent' | 'months', value = integer } or nil
---@return integer?
function records.reduce(months, reduction)
    if reduction == nil then return months end
    if type(reduction) ~= 'table' then return end

    local value = math.tointeger(reduction.value)
    if not value or value < 0 then return end

    if reduction.kind == 'percent' then
        if value > 100 then return end
        return math.floor(months * (100 - value) / 100)
    elseif reduction.kind == 'months' then
        if value > settings.maxMonths then return end
        return value
    end
end

return records
