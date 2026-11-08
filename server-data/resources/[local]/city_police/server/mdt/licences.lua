-- Licences: driver and weapon (qbx metadata.licences) and driving points.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local records = require 'server.records'
local db = require 'server.db'
local settings = require 'server.config'

local KINDS = { driver = true, weapon = true }

mdt.register('licences', function(_, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local person = citizenid and mdt.person(citizenid)
    if not person then return false, 'not_found' end

    local since = os.time() - settings.pointsDays * 86400
    local history = MySQL.query.await('SELECT id, charges, points, officer, created FROM city_police_records WHERE citizenid = ? AND points > 0 AND created >= ? ORDER BY id DESC', { citizenid, since }) or {}
    for _, row in ipairs(history) do row.charges = db.list(row.charges) end

    return true, {
        citizenid = citizenid,
        name = person.name,
        online = person.source ~= nil,
        licences = (person.metadata or {}).licences or {},
        points = records.points(citizenid),
        history = history,
    }
end)

mdt.register('setLicence', function(src, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local kind = data.licence

    if not citizenid or not KINDS[kind] or type(data.on) ~= 'boolean' then return false, 'invalid' end
    if kind == 'weapon' and not police.can(src, 'weaponLicence') then return false, 'no_permission' end

    local person = mdt.person(citizenid)
    if not person then return false, 'not_found' end

    local licences = (person.metadata or {}).licences or {}
    licences[kind] = data.on

    -- SetMetadata works for online and offline characters
    exports.qbx_core:SetMetadata(person.source or citizenid, 'licences', licences)

    if person.source then
        police.notify(person.source, data.on and 'licence_granted' or 'licence_revoked', data.on and 'success' or 'error', locale(('licence_%s'):format(kind)))
    end

    return true
end, 'licences')
