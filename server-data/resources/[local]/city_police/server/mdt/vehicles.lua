-- Vehicles: search by plate or owner, a vehicle's page, flagging plates.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local plates = require 'server.plates'
local records = require 'server.records'
local settings = require 'server.config'

local STATUSES = { stolen = true, wanted = true }

---@param row table player_vehicles row joined with the owner's charinfo
---@return table
local function brief(row)
    local charinfo = json.decode(row.charinfo or '{}') or {}
    local flag = plates.get(row.plate)

    return {
        plate = row.plate,
        model = row.vehicle,
        owner = charinfo.firstname and ('%s %s'):format(charinfo.firstname, charinfo.lastname) or nil,
        citizenid = row.citizenid,
        state = row.state,
        flag = flag and flag.status or nil,
    }
end

-- One search box for both: citizens whose name matches (to pick the owner) and cars whose plate matches
mdt.register('searchVehicles', function(_, data)
    local like = mdt.like(data.q)
    if not like then
        -- Nothing typed: the flagged plates
        local list = {}
        for plate, flag in pairs(plates.all()) do
            list[#list + 1] = { plate = plate, flag = flag.status, reason = flag.reason }
        end
        return true, { people = {}, vehicles = list }
    end

    local people = MySQL.query.await([[
        SELECT p.citizenid, p.charinfo, (SELECT COUNT(*) FROM player_vehicles v WHERE v.citizenid = p.citizenid) AS cars
        FROM players p
        WHERE CONCAT(JSON_VALUE(p.charinfo, '$.firstname'), ' ', JSON_VALUE(p.charinfo, '$.lastname')) LIKE ?
        ORDER BY JSON_VALUE(p.charinfo, '$.firstname'), JSON_VALUE(p.charinfo, '$.lastname') LIMIT ?
    ]], { like, settings.searchLimit }) or {}

    for i = 1, #people do
        local row = people[i]
        local charinfo = json.decode(row.charinfo or '{}') or {}

        people[i] = {
            citizenid = row.citizenid,
            name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or ''),
            cars = tonumber(row.cars) or 0,
            online = exports.qbx_core:GetPlayerByCitizenId(row.citizenid) ~= nil,
        }
    end

    local rows = MySQL.query.await([[
        SELECT v.plate, v.vehicle, v.citizenid, v.state, p.charinfo FROM player_vehicles v
        LEFT JOIN players p ON p.citizenid = v.citizenid
        WHERE v.plate LIKE ? LIMIT ?
    ]], { like, settings.searchLimit }) or {}

    local vehicles = {}
    for i = 1, #rows do vehicles[i] = brief(rows[i]) end

    return true, { people = people, vehicles = vehicles }
end, 'vehicles')

-- The owner's small profile beside a car: name, booking photo and every car they own
mdt.register('vehicleOwner', function(_, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local person = citizenid and mdt.person(citizenid)
    if not person then return false, 'not_found' end

    local rows = MySQL.query.await('SELECT plate, vehicle, state FROM player_vehicles WHERE citizenid = ? ORDER BY vehicle LIMIT 30', { citizenid }) or {}

    local vehicles = {}
    for i = 1, #rows do
        local flag = plates.get(rows[i].plate)
        vehicles[i] = { plate = rows[i].plate, model = rows[i].vehicle, state = rows[i].state, flag = flag and flag.status or nil }
    end

    return true, {
        citizenid = citizenid,
        name = person.name,
        phone = person.charinfo and person.charinfo.phone,
        online = person.source ~= nil,
        photo = records.photo(citizenid),
        vehicles = vehicles,
    }
end, 'vehicles')

mdt.register('vehicle', function(_, data)
    local plate = mdt.plate(data.plate)
    if not plate then return false, 'invalid' end

    local row = MySQL.single.await([[
        SELECT v.plate, v.vehicle, v.citizenid, v.state, v.garage, p.charinfo FROM player_vehicles v
        LEFT JOIN players p ON p.citizenid = v.citizenid WHERE v.plate = ?
    ]], { plate })

    local flag = plates.get(plate)
    local impounds = MySQL.query.await('SELECT id, reason, fee, officer, created, released_at FROM city_police_impounds WHERE plate = ? ORDER BY id DESC LIMIT 10', { plate }) or {}

    -- A plate nobody owns (a local's car) can still be flagged
    local result = row and brief(row) or { plate = plate }
    result.garage = row and row.garage
    local model = row and type(row.vehicle) == 'string' and row.vehicle:lower()
    result.image = model and model:match('^[%w_]+$') and settings.vehicleImageUrl:format(model) or nil
    result.registered = row ~= nil
    result.flag = flag and { status = flag.status, reason = flag.reason, by = flag.by_name, at = flag.created } or nil
    result.impounds = impounds

    return true, result
end, 'vehicles')

mdt.register('flagPlate', function(src, data)
    local plate = mdt.plate(data.plate)
    local reason = police.clean(data.reason, settings.text.line)

    if not plate or not STATUSES[data.status] or reason == '' then return false, 'invalid' end

    plates.flag(plate, data.status, reason, police.name(src))

    return true
end)

mdt.register('clearPlate', function(_, data)
    local plate = mdt.plate(data.plate)
    if not plate then return false, 'invalid' end

    plates.clear(plate)

    return true
end, 'flagPlate')
