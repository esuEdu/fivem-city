-- Arrest warrants: sergeants and up issue and cancel them; any officer marks one served.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local records = require 'server.records'
local settings = require 'server.config'
local db = require 'server.db'

local STATUSES = { active = true, served = true, cancelled = true }

mdt.register('warrants', function(_, data)
    local status = STATUSES[data.status] and data.status or 'active'
    local rows

    if status == 'active' then
        rows = MySQL.query.await("SELECT * FROM city_police_warrants WHERE status = 'active' AND expires > ? ORDER BY id DESC LIMIT 100", { os.time() })
    else
        rows = MySQL.query.await('SELECT * FROM city_police_warrants WHERE status = ? ORDER BY id DESC LIMIT 100', { status })
    end

    for _, row in ipairs(rows or {}) do row.charges = db.list(row.charges) end

    return true, rows or {}
end)

mdt.register('issueWarrant', function(src, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local person = citizenid and mdt.person(citizenid)
    local reason = police.clean(data.reason, settings.text.line)
    local charges = records.total(data.charges)
    local days = math.tointeger(data.days) or settings.warrantDays

    if not person or reason == '' or not charges or days < 1 or days > 30 then return false, 'invalid' end

    local now = os.time()
    local id = MySQL.insert.await('INSERT INTO city_police_warrants (citizenid, name, reason, charges, issued_by, created, expires) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenid, person.name, reason, json.encode(charges), police.name(src), now, now + days * 86400,
    })

    return id ~= nil, id
end)

mdt.register('closeWarrant', function(src, data)
    local id = mdt.id(data.id)
    local status = data.status

    if not id or (status ~= 'served' and status ~= 'cancelled') then return false, 'invalid' end

    -- Cancelling takes the same grade as issuing; serving any officer
    if status == 'cancelled' and not police.can(src, 'issueWarrant') then return false, 'no_permission' end

    local changed = MySQL.update.await("UPDATE city_police_warrants SET status = ?, closed_by = ?, closed_at = ? WHERE id = ? AND status = 'active'", {
        status, police.name(src), os.time(), id,
    })

    return changed > 0, changed > 0 and nil or 'not_found'
end, 'warrants')

---A warrant from another server script (city_prison, for an escape). No charges; the reason says why.
---@param data { citizenid: string, name: string, reason: string, issuedBy: string, days?: integer }
---@return integer? id
exports('IssueWarrant', function(data)
    if type(data) ~= 'table' or type(data.citizenid) ~= 'string' or type(data.name) ~= 'string' then return end

    local reason = police.clean(data.reason, settings.text.line)
    local days = math.tointeger(data.days) or settings.warrantDays
    if reason == '' or days < 1 or days > 30 then return end

    local now = os.time()

    return MySQL.insert.await('INSERT INTO city_police_warrants (citizenid, name, reason, charges, issued_by, created, expires) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.citizenid, data.name, reason, '[]', police.clean(data.issuedBy, settings.text.short), now, now + days * 86400,
    })
end)
