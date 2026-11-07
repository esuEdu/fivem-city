-- Officers: their saved row (callsign, certifications, hours), who is on duty right now, their status and call, and
-- the shifts that count their hours. Duty itself is qbx_core's job.onduty; this follows it.

local db = require 'server.db'
local police = require 'server.police'

local roster = {}

---@class Unit
---@field citizenid string
---@field name string
---@field callsign string?
---@field certs table<string, true>
---@field status string
---@field call integer?
---@field since integer duty start (os.time)
---@field shift integer? shift row id

---@type table<integer, Unit>
local units = {}
local lastCount = -1

local VALID_STATUS = {}
for _, status in ipairs(Config.Statuses) do VALID_STATUS[status] = true end

---@param certs table
---@return table<string, true>
local function certSet(certs)
    local set = {}

    for _, id in ipairs(certs) do
        if type(id) == 'string' then set[id] = true end
    end

    return set
end

---The saved officer row, created the first time.
---@param citizenid string
---@param name string
---@return table
function roster.row(citizenid, name)
    local row = MySQL.single.await('SELECT * FROM city_police_officers WHERE citizenid = ?', { citizenid })
    if row then return row end

    MySQL.insert.await('INSERT IGNORE INTO city_police_officers (citizenid, name, hired_at) VALUES (?, ?, ?)', { citizenid, name, os.time() })

    return { citizenid = citizenid, name = name, callsign = nil, certs = '[]', minutes = 0, hired_at = os.time() }
end

-- Tells everyone how many officers are on duty (robbery scripts listen to police:SetCopCount), only when it changes
local function broadcastCount()
    local count = #police.onDutyList()
    if count == lastCount then return end

    lastCount = count
    TriggerClientEvent('police:SetCopCount', -1, count)
end

---@param src integer
local function start(src)
    if units[src] then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local name = police.fullName(player)
    local row = roster.row(citizenid, name)
    local now = os.time()

    units[src] = {
        citizenid = citizenid,
        name = name,
        callsign = row.callsign,
        certs = certSet(db.list(row.certs)),
        status = 'available',
        since = now,
    }

    MySQL.update('UPDATE city_police_officers SET name = ?, last_duty = ? WHERE citizenid = ?', { name, now, citizenid })
    MySQL.insert('INSERT INTO city_police_shifts (citizenid, started) VALUES (?, ?)', { citizenid, now }, function(id)
        if units[src] and units[src].citizenid == citizenid then units[src].shift = id end
    end)

    TriggerClientEvent('city_police:client:duty', src, true)
    TriggerEvent('city_police:server:unitsChanged')
end

---@param src integer
local function stop(src)
    local unit = units[src]
    if not unit then return end

    units[src] = nil

    local now = os.time()
    local minutes = math.floor((now - unit.since) / 60)

    MySQL.update('UPDATE city_police_officers SET minutes = minutes + ?, last_duty = ? WHERE citizenid = ?', { minutes, now, unit.citizenid })

    if unit.shift then
        MySQL.update('UPDATE city_police_shifts SET ended = ? WHERE id = ?', { now, unit.shift })
    else
        MySQL.update('UPDATE city_police_shifts SET ended = ? WHERE citizenid = ? AND ended IS NULL', { now, unit.citizenid })
    end

    if GetPlayerName(src) then TriggerClientEvent('city_police:client:duty', src, false) end

    TriggerEvent('city_police:server:unitsChanged')
    TriggerEvent('city_police:server:offDuty', src)
end

---Brings the unit list in line with qbx_core's duty for one player.
---@param src integer
function roster.sync(src)
    if police.onDuty(src) then start(src) else stop(src) end

    broadcastCount()
end

---@param src integer
---@return Unit?
function roster.unit(src)
    return units[src]
end

---@return table<integer, Unit>
function roster.all()
    return units
end

---@param src integer
---@param cert string
---@return boolean
function roster.hasCert(src, cert)
    local unit = units[src]

    return unit ~= nil and unit.certs[cert] == true
end

---@param src integer
---@param status unknown
---@return boolean
function roster.setStatus(src, status)
    local unit = units[src]
    if not unit or not VALID_STATUS[status] then return false end

    unit.status = status
    TriggerEvent('city_police:server:unitsChanged')

    return true
end

---@param src integer
---@param call integer?
function roster.setCall(src, call)
    local unit = units[src]
    if not unit then return end

    unit.call = call
    if call and unit.status == 'available' then unit.status = 'enroute' end
    if not call and (unit.status == 'enroute' or unit.status == 'onscene') then unit.status = 'available' end

    TriggerEvent('city_police:server:unitsChanged')
end

---@param src integer
---@param callsign string
function roster.setCallsign(src, callsign)
    local unit = units[src]
    if not unit then return end

    unit.callsign = callsign
    MySQL.update('UPDATE city_police_officers SET callsign = ? WHERE citizenid = ?', { callsign, unit.citizenid })
    TriggerEvent('city_police:server:unitsChanged')
end

---Someone's certifications changed in the MDT: refresh the on-duty copy.
---@param citizenid string
---@param certs string[]
function roster.updateCerts(citizenid, certs)
    for _, unit in pairs(units) do
        if unit.citizenid == citizenid then unit.certs = certSet(certs) end
    end
end

AddEventHandler('QBCore:Server:SetDuty', function(src)
    roster.sync(src)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    roster.sync(src)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = type(player) == 'table' and player.PlayerData and player.PlayerData.source
    if src then roster.sync(src) end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    stop(src)
    broadcastCount()
end)

AddEventHandler('playerDropped', function()
    stop(source)
    broadcastCount()
end)

-- Shifts still open when the resource stops are closed, so hours aren't lost
AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(units) do stop(src) end
end)

CreateThread(function()
    db.wait()

    -- Shifts left open by a crash end where they started (no hours counted for them)
    MySQL.update.await('UPDATE city_police_shifts SET ended = started WHERE ended IS NULL')

    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        roster.sync(src)
    end
end)

return roster
