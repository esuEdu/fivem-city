-- Vehicles: search by plate or owner, a vehicle's page, flagging plates.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local plates = require 'server.plates'
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

mdt.register('searchVehicles', function(_, data)
    local like = mdt.like(data.q)
    if not like then
        -- Nothing typed: the flagged plates
        local list = {}
        for plate, flag in pairs(plates.all()) do
            list[#list + 1] = { plate = plate, flag = flag.status, reason = flag.reason }
        end
        return true, list
    end

    local rows = MySQL.query.await([[
        SELECT v.plate, v.vehicle, v.citizenid, v.state, p.charinfo FROM player_vehicles v
        LEFT JOIN players p ON p.citizenid = v.citizenid
        WHERE v.plate LIKE ? OR CONCAT(JSON_VALUE(p.charinfo, '$.firstname'), ' ', JSON_VALUE(p.charinfo, '$.lastname')) LIKE ?
        LIMIT ?
    ]], { like, like, settings.searchLimit }) or {}

    local list = {}
    for i = 1, #rows do list[i] = brief(rows[i]) end

    return true, list
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
