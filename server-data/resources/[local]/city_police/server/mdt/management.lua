-- Certifications (lieutenants and up give them) and Management (the chief): members, hours, hire, rank, fire, notices.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local roster = require 'server.roster'
local db = require 'server.db'

local WEEK = 7 * 86400
local CERTS = {}
for _, cert in ipairs(Config.Certs) do CERTS[cert.id] = true end

---Everyone with the police job (online or not), with their officer row and hours this week.
---@return table[]
local function members()
    local list = {}
    local weekStart = os.time() - WEEK

    local week = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid, SUM(COALESCE(ended, UNIX_TIMESTAMP()) - started) AS seconds FROM city_police_shifts WHERE started >= ? GROUP BY citizenid', { weekStart }) or {}) do
        week[row.citizenid] = tonumber(row.seconds) or 0
    end

    local rows = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM city_police_officers') or {}) do rows[row.citizenid] = row end

    local onDuty = {}
    for src, unit in pairs(roster.all()) do onDuty[unit.citizenid] = src end

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        local row = rows[member.citizenid]
        local person = row and { name = row.name } or mdt.person(member.citizenid)

        list[#list + 1] = {
            citizenid = member.citizenid,
            name = person and person.name or member.citizenid,
            grade = member.grade,
            callsign = row and row.callsign,
            certs = row and db.list(row.certs) or {},
            minutes = row and row.minutes or 0,
            weekMinutes = math.floor((week[member.citizenid] or 0) / 60),
            lastDuty = row and row.last_duty,
            onDuty = onDuty[member.citizenid] ~= nil,
            online = exports.qbx_core:GetPlayerByCitizenId(member.citizenid) ~= nil,
        }
    end

    table.sort(list, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)

    return list
end

-- The Certifications and Management tabs list the members; every officer sees Management, the chief acts on it
mdt.register('members', function()
    return true, members()
end, 'app')

mdt.register('setCert', function(src, data)
    local citizenid = mdt.citizenid(data.citizenid)
    if not citizenid or not CERTS[data.cert] or type(data.on) ~= 'boolean' then return false, 'invalid' end
    if citizenid == police.citizenid(src) then return false, 'self' end

    local row = MySQL.single.await('SELECT certs FROM city_police_officers WHERE citizenid = ?', { citizenid })
    local person = not row and mdt.person(citizenid)
    if not row and not person then return false, 'not_found' end

    local certs, set = {}, {}
    for _, id in ipairs(row and db.list(row.certs) or {}) do
        if CERTS[id] and id ~= data.cert then set[id] = true end
    end
    if data.on then set[data.cert] = true end
    for id in pairs(set) do certs[#certs + 1] = id end

    if row then
        MySQL.update.await('UPDATE city_police_officers SET certs = ? WHERE citizenid = ?', { json.encode(certs), citizenid })
    else
        MySQL.insert.await('INSERT INTO city_police_officers (citizenid, name, certs, hired_at) VALUES (?, ?, ?, ?)', { citizenid, person.name, json.encode(certs), os.time() })
    end

    roster.updateCerts(citizenid, certs)

    return true
end, 'grantCert')

---A member the chief may change: in the job, below the chief's own grade, not themselves.
---@param src integer
---@param citizenid unknown
---@return string? citizenid
---@return integer? grade
local function subordinate(src, citizenid)
    citizenid = mdt.citizenid(citizenid)
    if not citizenid or citizenid == police.citizenid(src) then return end

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        if member.citizenid == citizenid and member.grade < police.grade(src) then return citizenid, member.grade end
    end
end

mdt.register('setGrade', function(src, data)
    local citizenid = subordinate(src, data.citizenid)
    local grade = math.tointeger(data.grade)
    local job = exports.qbx_core:GetJob(Config.Job)

    if not citizenid or not grade or not job.grades[grade] or grade >= police.grade(src) then return false, 'invalid' end

    local ok = exports.qbx_core:AddPlayerToJob(citizenid, Config.Job, grade)

    return ok == true, ok ~= true and 'failed' or nil
end, 'management')

mdt.register('fire', function(src, data)
    local citizenid = subordinate(src, data.citizenid)
    if not citizenid then return false, 'invalid' end

    local ok = exports.qbx_core:RemovePlayerFromJob(citizenid, Config.Job)

    return ok == true, ok ~= true and 'failed' or nil
end, 'management')

---@param citizenid string
---@return boolean
local function isMember(citizenid)
    for _, member in ipairs(exports.qbx_core:GetGroupMembers(Config.Job, 'job') or {}) do
        if member.citizenid == citizenid then return true end
    end

    return false
end

---@type table<integer, true> players with an offer on screen
local pendingOffers = {}

-- The chief offers the job to any online player by server id; the player accepts or declines on their screen and starts
-- at the lowest grade. The chief hears the answer.
mdt.register('offer', function(src, data)
    local target = math.tointeger(data.target)
    local offered = target and target ~= src and exports.qbx_core:GetPlayer(target)
    if not offered then return false, 'no_player' end
    if isMember(offered.PlayerData.citizenid) then return false, 'already' end
    if pendingOffers[target] then return false, 'pending' end

    pendingOffers[target] = true

    local citizenid = offered.PlayerData.citizenid
    local name = police.fullName(offered)

    CreateThread(function()
        local accepted = lib.callback.await('city_police:jobOffer', target, police.name(src)) == true
        pendingOffers[target] = nil

        if police.citizenid(target) ~= citizenid then return end

        -- The chief may have lost the grade, or someone else hired them, while the offer was open
        if accepted and police.can(src, 'management') and not isMember(citizenid) and exports.qbx_core:SetJob(target, Config.Job, 0) then
            roster.row(citizenid, name)
            police.notify(target, 'hired_you', 'success')
            police.notify(src, 'offer_accepted', 'success', name)
            TriggerClientEvent('city_police:client:mdtRefresh', src, { members = true })
            return
        end

        if GetPlayerName(src) then police.notify(src, 'offer_declined', 'error', name) end
    end)

    return true, name
end, 'management')

AddEventHandler('playerDropped', function()
    pendingOffers[source] = nil
end)

mdt.register('notices', function()
    return true, MySQL.query.await('SELECT id, text, author, created FROM city_police_notices ORDER BY id DESC LIMIT 30') or {}
end, 'app')

mdt.register('addNotice', function(src, data)
    local text = police.clean(data.text, 500)
    if text == '' then return false, 'invalid' end

    MySQL.insert.await('INSERT INTO city_police_notices (text, author, created) VALUES (?, ?, ?)', { text, police.name(src), os.time() })

    return true
end, 'notices')

mdt.register('deleteNotice', function(_, data)
    local id = mdt.id(data.id)
    if not id then return false, 'invalid' end

    MySQL.update.await('DELETE FROM city_police_notices WHERE id = ?', { id })

    return true
end, 'notices')

