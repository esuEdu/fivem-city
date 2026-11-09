-- Cases (incident reports): written and edited by officers (their own; sergeants and up any). A case has crime tags,
-- the officers, civilians and criminals involved (each criminal with their charges), vehicles and photos. Charges are
-- only listed here; the fine or the arrest is made from the case or the Prison tab, through mdt 'charge'.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local records = require 'server.records'
local settings = require 'server.config'
local db = require 'server.db'

local ROLES = { officer = true, civilian = true, criminal = true }
local OLD_ROLES = { suspect = 'criminal', victim = 'civilian', witness = 'civilian' }
local MAX_PEOPLE, MAX_PLATES, MAX_EVIDENCE, MAX_TAGS, MAX_PHOTOS = 20, 10, 10, 8, 6
local PHONE_PHOTOS = 12 -- newest phone photos offered when attaching one
local PHOTO_SECONDS = 2 -- between two photos attached by one officer
local ORPHAN_SECONDS = 86400 -- attached photos never saved into a case are deleted after a day

local TAGS = {}
for _, tag in ipairs(Config.CaseTags) do TAGS[tag.id] = true end

local lastPhoto = {}

---@param row table
---@return table
local function decode(row)
    row.people = db.list(row.people)
    row.plates = db.list(row.plates)
    row.evidence = db.list(row.evidence)
    row.tags = db.list(row.tags)
    row.photos = db.list(row.photos)

    for _, person in ipairs(row.people) do
        person.role = OLD_ROLES[person.role] or person.role
        person.charges = person.role == 'criminal' and (person.charges or {}) or nil
    end

    return row
end

mdt.register('reports', function(_, data)
    local like = mdt.like(data.q)
    local rows = like
        and MySQL.query.await('SELECT id, kind, title, place, tags, author, created, updated FROM city_police_reports WHERE title LIKE ? OR author LIKE ? OR place LIKE ? ORDER BY id DESC LIMIT 50', { like, like, like })
        or MySQL.query.await('SELECT id, kind, title, place, tags, author, created, updated FROM city_police_reports ORDER BY id DESC LIMIT 50')

    for _, row in ipairs(rows or {}) do row.tags = db.list(row.tags) end

    return true, rows or {}
end)

mdt.register('report', function(src, data)
    local id = mdt.id(data.id)
    local row = id and MySQL.single.await('SELECT * FROM city_police_reports WHERE id = ?', { id })
    if not row then return false, 'not_found' end

    row = decode(row)
    row.canEdit = row.author_cid == police.citizenid(src) or police.can(src, 'editAnyReport')

    -- Evidence bags attached, with what the lab found
    if #row.evidence > 0 and police.can(src, 'evidence') then
        local ids = {}
        for _, value in ipairs(row.evidence) do
            if math.tointeger(value) then ids[#ids + 1] = math.tointeger(value) end
        end

        row.evidenceItems = #ids > 0 and MySQL.query.await('SELECT id, kind, place, analyzed_at FROM city_police_evidence WHERE id IN (?)', { ids }) or {}
    end

    -- Who of the people is in the city now (the fine button needs them online)
    for _, person in ipairs(row.people) do
        local online = exports.qbx_core:GetPlayerByCitizenId(person.citizenid)
        person.id = online and online.PlayerData.source or nil
    end

    return true, row
end, 'reports')

---A criminal's charges as records.total checks them, without titles (those come from the penal code).
---@param list unknown
---@return table[]? charges, table? totals
local function chargesOf(list)
    if type(list) ~= 'table' then return end
    if #list == 0 then return {}, { months = 0, fine = 0, points = 0 } end

    local charges, totals = records.total(list)
    if not charges then return end

    local out = {}
    for i, charge in ipairs(charges) do out[i] = { id = charge.id, count = charge.count } end

    return out, totals
end

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

            local charges
            if entry.role == 'criminal' then
                charges = chargesOf(entry.charges or {})
                if not charges then return end
            end

            people[#people + 1] = { citizenid = citizenid, name = person.name, role = entry.role, charges = charges }
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
---@param max integer
---@return integer[]?
local function idsOf(list, max)
    if type(list) ~= 'table' or #list > max then return end

    local out = {}
    for _, value in ipairs(list) do
        local id = mdt.id(value)
        if not id then return end
        out[#out + 1] = id
    end

    return out
end

---@param list unknown
---@return string[]?
local function tagsOf(list)
    if type(list) ~= 'table' or #list > MAX_TAGS then return end

    local out, seen = {}, {}
    for _, value in ipairs(list) do
        if not TAGS[value] then return end
        if not seen[value] then
            seen[value] = true
            out[#out + 1] = value
        end
    end

    return out
end

---Photos must be ones this officer attached and that no other case holds yet (or already this case's).
---@param src integer
---@param ids integer[]
---@param caseId integer?
---@return boolean
local function photosAllowed(src, ids, caseId)
    if #ids == 0 then return true end

    local rows = MySQL.query.await('SELECT id, report_id, officer_cid FROM city_police_case_photos WHERE id IN (?)', { ids }) or {}
    if #rows ~= #ids then return false end

    local citizenid = police.citizenid(src)
    for _, row in ipairs(rows) do
        local mine = row.report_id == nil and row.officer_cid == citizenid
        if not mine and (not caseId or row.report_id ~= caseId) then return false end
    end

    return true
end

mdt.register('saveReport', function(src, data)
    local title = police.clean(data.title, 100)
    local place = police.clean(data.place, 100)
    local body = police.cleanLong(data.body, settings.text.long)
    local people, plates = peopleOf(data.people or {}), platesOf(data.plates or {})
    local evidence, photos, tags = idsOf(data.evidence or {}, MAX_EVIDENCE), idsOf(data.photos or {}, MAX_PHOTOS), tagsOf(data.tags or {})

    if title == '' or body == '' or not people or not plates or not evidence or not photos or not tags then return false, 'invalid' end

    local now = os.time()
    local id = mdt.id(data.id)

    if id then
        local row = MySQL.single.await('SELECT author_cid FROM city_police_reports WHERE id = ?', { id })
        if not row then return false, 'not_found' end
        if row.author_cid ~= police.citizenid(src) and not police.can(src, 'editAnyReport') then return false, 'no_permission' end
        if not photosAllowed(src, photos, id) then return false, 'invalid' end

        MySQL.update.await('UPDATE city_police_reports SET title = ?, place = ?, body = ?, people = ?, plates = ?, evidence = ?, tags = ?, photos = ?, updated = ? WHERE id = ?', {
            title, place, body, json.encode(people), json.encode(plates), json.encode(evidence), json.encode(tags), json.encode(photos), now, id,
        })
    else
        if not photosAllowed(src, photos) then return false, 'invalid' end

        id = MySQL.insert.await('INSERT INTO city_police_reports (kind, title, place, body, people, plates, evidence, tags, photos, author, author_cid, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            'incident', title, place, body, json.encode(people), json.encode(plates), json.encode(evidence), json.encode(tags), json.encode(photos), police.name(src), police.citizenid(src), now, now,
        })
        if not id then return false, 'failed' end
    end

    -- Photos taken off the case go; the ones on it belong to it
    if #photos > 0 then
        MySQL.update.await('UPDATE city_police_case_photos SET report_id = ? WHERE id IN (?)', { id, photos })
        MySQL.update.await('DELETE FROM city_police_case_photos WHERE report_id = ? AND id NOT IN (?)', { id, photos })
    else
        MySQL.update.await('DELETE FROM city_police_case_photos WHERE report_id = ?', { id })
    end

    return true, id
end, 'reports')

-- Cases where this person is a criminal, with their charges: the Prison tab attaches one to an arrest
mdt.register('personCases', function(_, data)
    local citizenid = mdt.citizenid(data.citizenid)
    if not citizenid then return false, 'invalid' end

    local like = mdt.like(data.q)
    local pattern = ('%%"%s"%%'):format(citizenid)
    local rows = like
        and MySQL.query.await('SELECT id, title, people, created FROM city_police_reports WHERE people LIKE ? AND title LIKE ? ORDER BY id DESC LIMIT 20', { pattern, like })
        or MySQL.query.await('SELECT id, title, people, created FROM city_police_reports WHERE people LIKE ? ORDER BY id DESC LIMIT 20', { pattern })

    local list = {}
    for _, row in ipairs(rows or {}) do
        for _, person in ipairs(decode(row).people) do
            if person.citizenid == citizenid and person.role == 'criminal' then
                list[#list + 1] = { id = row.id, title = row.title, created = row.created, charges = person.charges or {} }
                break
            end
        end
    end

    return true, list
end, 'charge')

-- The officer's newest phone photos, to attach one as evidence
mdt.register('phonePhotos', function(src)
    if GetResourceState('city_phone_photos') ~= 'started' then return true, {} end

    local list = exports.city_phone_photos:List(police.citizenid(src)) or {}
    local ids = {}
    for i = 1, math.min(#list, PHONE_PHOTOS) do ids[i] = list[i].id end

    return true, ids
end, 'reports')

mdt.register('phonePhoto', function(src, data)
    local id = math.tointeger(data.id)
    if not id or GetResourceState('city_phone_photos') ~= 'started' then return false, 'invalid' end

    local image = exports.city_phone_photos:Data(police.citizenid(src), id)
    if not image then return false, 'not_found' end

    return true, image
end, 'reports')

-- Copies one of the officer's phone photos into the police files (the phone copy can be deleted later)
mdt.register('attachPhoto', function(src, data)
    local id = math.tointeger(data.id)
    if not id or GetResourceState('city_phone_photos') ~= 'started' then return false, 'invalid' end

    local now = os.time()
    if lastPhoto[src] and now - lastPhoto[src] < PHOTO_SECONDS then return false, 'busy' end
    lastPhoto[src] = now

    local citizenid = police.citizenid(src)

    -- Photos attached but not saved into a case yet stay few (they cost database space until a case holds them)
    local loose = MySQL.scalar.await('SELECT COUNT(*) FROM city_police_case_photos WHERE officer_cid = ? AND report_id IS NULL', { citizenid }) or 0
    if loose >= MAX_PHOTOS * 2 then return false, 'busy' end

    local image = exports.city_phone_photos:Data(citizenid, id)
    if not image then return false, 'not_found' end

    local photoId = MySQL.insert.await('INSERT INTO city_police_case_photos (officer_cid, data, created) VALUES (?, ?, ?)', { citizenid, image, now })

    return photoId ~= nil, photoId
end, 'reports')

mdt.register('casePhoto', function(_, data)
    local id = mdt.id(data.id)
    local image = id and MySQL.scalar.await('SELECT data FROM city_police_case_photos WHERE id = ?', { id })
    if not image then return false, 'not_found' end

    return true, image
end, 'reports')

AddEventHandler('playerDropped', function()
    lastPhoto[source] = nil
end)

CreateThread(function()
    db.wait()
    MySQL.update.await('DELETE FROM city_police_case_photos WHERE report_id IS NULL AND created < ?', { os.time() - ORPHAN_SECONDS })
end)
