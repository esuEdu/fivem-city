-- Incident reports: written and edited by officers (their own; sergeants and up any).

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local settings = require 'server.config'
local db = require 'server.db'

local KINDS = { incident = true, arrest = true, traffic = true, investigation = true, other = true }
local ROLES = { suspect = true, victim = true, witness = true, officer = true }
local MAX_PEOPLE, MAX_PLATES, MAX_EVIDENCE = 15, 10, 10

---@param row table
---@return table
local function decode(row)
    row.people = db.list(row.people)
    row.plates = db.list(row.plates)
    row.evidence = db.list(row.evidence)

    return row
end

mdt.register('reports', function(_, data)
    local like = mdt.like(data.q)
    local rows = like
        and MySQL.query.await('SELECT id, kind, title, place, author, created, updated FROM city_police_reports WHERE title LIKE ? OR author LIKE ? OR place LIKE ? ORDER BY id DESC LIMIT 50', { like, like, like })
        or MySQL.query.await('SELECT id, kind, title, place, author, created, updated FROM city_police_reports ORDER BY id DESC LIMIT 50')

    return true, rows or {}
end)

mdt.register('report', function(src, data)
    local id = mdt.id(data.id)
    local row = id and MySQL.single.await('SELECT * FROM city_police_reports WHERE id = ?', { id })
    if not row then return false, 'not_found' end

    row = decode(row)
    row.canEdit = row.author_cid == police.citizenid(src) or police.can(src, 'editAnyReport')

    -- Evidence attached, with what the lab found
    if #row.evidence > 0 then
        local ids = {}
        for _, value in ipairs(row.evidence) do
            if math.tointeger(value) then ids[#ids + 1] = math.tointeger(value) end
        end

        row.evidenceItems = #ids > 0 and MySQL.query.await('SELECT id, kind, place, analyzed_at FROM city_police_evidence WHERE id IN (?)', { ids }) or {}
    end

    return true, row
end, 'reports')

---@param list unknown
---@return table[]?
local function peopleOf(list)
    if type(list) ~= 'table' or #list > MAX_PEOPLE then return end

    local people, seen = {}, {}

    for _, entry in ipairs(list) do
        local citizenid = type(entry) == 'table' and mdt.citizenid(entry.citizenid)
        if not citizenid or not ROLES[entry.role] then return end

        if not seen[citizenid] then
            seen[citizenid] = true

            local person = mdt.person(citizenid)
            if not person then return end

            people[#people + 1] = { citizenid = citizenid, name = person.name, role = entry.role }
        end
    end

    return people
end

---@param list unknown
---@return string[]?
local function platesOf(list)
    if type(list) ~= 'table' or #list > MAX_PLATES then return end

    local out = {}
    for _, value in ipairs(list) do
        local plate = mdt.plate(value)
        if not plate then return end
        out[#out + 1] = plate
    end

    return out
end

---@param list unknown
---@return integer[]?
local function evidenceOf(list)
    if type(list) ~= 'table' or #list > MAX_EVIDENCE then return end

    local out = {}
    for _, value in ipairs(list) do
        local id = mdt.id(value)
        if not id then return end
        out[#out + 1] = id
    end

    return out
end

mdt.register('saveReport', function(src, data)
    local title = police.clean(data.title, 100)
    local place = police.clean(data.place, 100)
    local body = police.cleanLong(data.body, settings.text.long)
    local people, plates, evidence = peopleOf(data.people or {}), platesOf(data.plates or {}), evidenceOf(data.evidence or {})

    if not KINDS[data.kind] or title == '' or body == '' or not people or not plates or not evidence then return false, 'invalid' end

    local now = os.time()
    local id = mdt.id(data.id)

    if id then
        local row = MySQL.single.await('SELECT author_cid FROM city_police_reports WHERE id = ?', { id })
        if not row then return false, 'not_found' end
        if row.author_cid ~= police.citizenid(src) and not police.can(src, 'editAnyReport') then return false, 'no_permission' end

        MySQL.update.await('UPDATE city_police_reports SET kind = ?, title = ?, place = ?, body = ?, people = ?, plates = ?, evidence = ?, updated = ? WHERE id = ?', {
            data.kind, title, place, body, json.encode(people), json.encode(plates), json.encode(evidence), now, id,
        })

        return true, id
    end

    id = MySQL.insert.await('INSERT INTO city_police_reports (kind, title, place, body, people, plates, evidence, author, author_cid, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.kind, title, place, body, json.encode(people), json.encode(plates), json.encode(evidence), police.name(src), police.citizenid(src), now, now,
    })

    return id ~= nil, id
end, 'reports')
