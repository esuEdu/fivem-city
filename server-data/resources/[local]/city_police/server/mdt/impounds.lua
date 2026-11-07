-- Impounds: an officer impounds the car in front of them; it stays in player_vehicles with state 2 until released
-- (state 0, so city_garages' impound lot has it). The fee is a bank bill to the owner on release.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local settings = require 'server.config'

---@param row table city_police_impounds row
---@param releasedBy string
---@param payer integer? who gets the fee bill
---@return boolean, string?
local function release(row, releasedBy, payer)
    if row.fee > 0 then
        if not payer then return false, 'offline' end
        if not exports.city_bank:CreateBill(payer, row.fee, locale('impound_bill', row.plate)) then return false, 'bill_failed' end
    end

    MySQL.update.await('UPDATE city_police_impounds SET released_at = ?, released_by = ? WHERE id = ?', { os.time(), releasedBy, row.id })
    MySQL.update.await('UPDATE player_vehicles SET state = 0, depotprice = 0 WHERE plate = ? AND state = 2', { row.plate })

    return true
end

mdt.register('impounds', function()
    local rows = MySQL.query.await('SELECT * FROM city_police_impounds WHERE released_at IS NULL ORDER BY id DESC LIMIT 100') or {}
    local items = exports.city_inventory:GetInventoryItems('city_police_evidence') or {}
    local locker = {}

    for _, item in pairs(items) do
        locker[#locker + 1] = { label = item.label, count = item.count, description = item.metadata and item.metadata.description }
    end

    return true, { vehicles = rows, locker = locker }
end, 'impound')

mdt.register('impound', function(src, data)
    local netId = math.tointeger(data.netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false, 'no_vehicle' end
    if not police.near(src, GetEntityCoords(vehicle), Config.Ranges.vehicle) then return false, 'too_far' end

    local reason = police.clean(data.reason, settings.text.line)
    local fee = math.tointeger(data.fee) or settings.impoundFee
    local hours = math.tointeger(data.hours) or 0

    if reason == '' or fee < 0 or fee > settings.maxImpoundFee or hours < 0 or hours > settings.maxHoldHours then return false, 'invalid' end

    local plate = GetVehicleNumberPlateText(vehicle):match('^%s*(.-)%s*$')
    local owned = MySQL.single.await('SELECT citizenid, vehicle FROM player_vehicles WHERE plate = ?', { plate })
    local now = os.time()

    if owned then
        MySQL.update.await('UPDATE player_vehicles SET state = 2, depotprice = 0 WHERE plate = ?', { plate })
        MySQL.insert.await('INSERT INTO city_police_impounds (plate, citizenid, model, reason, fee, hold_until, officer, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            plate, owned.citizenid, owned.vehicle, reason, fee, now + hours * 3600, police.name(src), now,
        })
    end

    DeleteEntity(vehicle)

    return true, { owned = owned ~= nil, plate = plate }
end, 'impound')

mdt.register('release', function(src, data)
    local id = mdt.id(data.id)
    local row = id and MySQL.single.await('SELECT * FROM city_police_impounds WHERE id = ? AND released_at IS NULL', { id })
    if not row then return false, 'not_found' end

    local owner = row.citizenid and exports.qbx_core:GetPlayerByCitizenId(row.citizenid)

    return release(row, police.name(src), owner and owner.PlayerData.source or nil)
end)

-- The owner at a station's impound desk: their cars past the hold time
lib.callback.register('city_police:myImpounds', function(source)
    local src = source
    local citizenid = police.citizenid(src)
    if not citizenid then return {} end

    return MySQL.query.await('SELECT id, plate, model, reason, fee, hold_until FROM city_police_impounds WHERE citizenid = ? AND released_at IS NULL', { citizenid }) or {}
end)

lib.callback.register('city_police:payImpound', function(source, id)
    local src = source
    local citizenid = police.citizenid(src)
    id = mdt.id(id)
    if not citizenid or not id then return false end

    local atDesk = false
    for _, station in ipairs(Config.Stations) do
        if station.impound and police.near(src, station.impound, Config.Ranges.place + 1.0) then atDesk = true end
    end
    if not atDesk then return false end

    local row = MySQL.single.await('SELECT * FROM city_police_impounds WHERE id = ? AND citizenid = ? AND released_at IS NULL', { id, citizenid })
    if not row then return false end
    if row.hold_until > os.time() then return false, 'on_hold', row.hold_until - os.time() end

    return release(row, police.name(src), src)
end)
