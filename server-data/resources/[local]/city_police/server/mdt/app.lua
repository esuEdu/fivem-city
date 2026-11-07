-- The MDT's start, Dashboard, Dispatch, Units and Map, and the live refresh sent to open MDTs.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local roster = require 'server.roster'
local dispatch = require 'server.dispatch'
local penal = require 'shared.penal'
local settings = require 'server.config'

local DAY = 86400

-- Live refresh: what changed goes to officers on duty at most once a second; their client passes it to the page
local pending = {}
local scheduled = false

---@param what string
local function refresh(what)
    pending[what] = true
    if scheduled then return end

    scheduled = true
    SetTimeout(1000, function()
        scheduled = false
        local list = pending
        pending = {}

        police.toOnDuty('city_police:client:mdtRefresh', list)
    end)
end

AddEventHandler('city_police:server:callsChanged', function() refresh('calls') end)
AddEventHandler('city_police:server:unitsChanged', function() refresh('units') end)

---@param src integer
---@return table
local function me(src)
    local player = exports.qbx_core:GetPlayer(src)
    local unit = roster.unit(src)
    local job = player.PlayerData.job
    local certs = {}

    for id in pairs(unit and unit.certs or {}) do certs[#certs + 1] = id end

    return {
        id = src,
        name = police.fullName(player),
        citizenid = player.PlayerData.citizenid,
        callsign = unit and unit.callsign,
        grade = job.grade.level,
        gradeLabel = job.grade.name,
        status = unit and unit.status,
        since = unit and unit.since,
        certs = certs,
    }
end

---Grade names from qbx_core, for the pages that show or change ranks.
---@return { level: integer, name: string }[]
local function grades()
    local job = exports.qbx_core:GetJob(Config.Job)
    local list = {}

    for level, grade in pairs(job and job.grades or {}) do
        list[#list + 1] = { level = level, name = grade.name }
    end

    table.sort(list, function(a, b) return a.level < b.level end)

    return list
end

mdt.register('app', function(src)
    local cameras = {}
    for index, camera in ipairs(Config.Cameras) do cameras[index] = { label = camera.label } end

    return true, {
        me = me(src),
        permissions = mdt.permissions(src),
        penal = penal,
        statuses = Config.Statuses,
        certs = Config.Certs,
        grades = grades(),
        cameras = cameras,
        maxFine = settings.maxFine,
        maxMonths = settings.maxMonths,
        impound = { fee = settings.impoundFee, maxFee = settings.maxImpoundFee, maxHours = settings.maxHoldHours },
        warrantDays = settings.warrantDays,
        maxPoints = settings.maxPoints,
        pointsDays = settings.pointsDays,
    }
end)

mdt.register('dashboard', function(src)
    local since = os.time() - DAY
    local unit = roster.unit(src)
    local calls = dispatch.list()
    local latest = {}

    for i = 1, math.min(#calls, 5) do latest[i] = dispatch.view(calls[i], src) end

    local units = 0
    for _ in pairs(roster.all()) do units = units + 1 end

    local counts = MySQL.single.await([[
        SELECT
            SUM(kind = 'arrest') AS arrests,
            SUM(kind = 'fine') AS fines,
            COALESCE(SUM(fine), 0) AS fined
        FROM city_police_records WHERE created >= ?
    ]], { since }) or {}

    local warrants = MySQL.scalar.await("SELECT COUNT(*) FROM city_police_warrants WHERE status = 'active' AND expires > ?", { os.time() }) or 0
    local notices = MySQL.query.await('SELECT id, text, author, created FROM city_police_notices ORDER BY id DESC LIMIT 5') or {}
    local impounds = MySQL.scalar.await('SELECT COUNT(*) FROM city_police_impounds WHERE released_at IS NULL') or 0

    return true, {
        me = me(src),
        shiftSeconds = unit and os.time() - unit.since or 0,
        openCalls = #calls,
        calls = latest,
        units = units,
        warrants = warrants,
        impounds = impounds,
        arrests = tonumber(counts.arrests) or 0,
        fines = tonumber(counts.fines) or 0,
        fined = tonumber(counts.fined) or 0,
        notices = notices,
    }
end)

mdt.register('calls', function(src)
    local list = {}

    for _, call in ipairs(dispatch.list()) do list[#list + 1] = dispatch.view(call, src) end

    return true, list
end, 'dispatch')

---@param src integer
---@param data table
---@return PoliceCall?
local function callOf(src, data)
    local call = dispatch.get(math.tointeger(data.id))
    if not call then police.warn(src, 'asked for a call that is gone') end

    return call
end

mdt.register('callAttach', function(src, data)
    local call = callOf(src, data)
    if not call then return false, 'gone' end

    dispatch.attach(src, call)

    return true, call.coords
end, 'dispatch')

mdt.register('callDetach', function(src, data)
    local call = callOf(src, data)
    if not call then return false, 'gone' end

    dispatch.detach(src, call)

    return true
end, 'dispatch')

mdt.register('callNote', function(src, data)
    local call = callOf(src, data)
    local text = police.clean(data.text, settings.text.line)
    if not call then return false, 'gone' end
    if text == '' then return false, 'invalid' end

    dispatch.note(src, call, text)

    return true
end, 'dispatch')

mdt.register('callClose', function(src, data)
    local call = callOf(src, data)
    if not call then return false, 'gone' end

    -- Whoever is on it, or a sergeant and up, closes it
    if not call.units[src] and police.grade(src) < Config.Permissions.issueWarrant then return false, 'not_attached' end

    dispatch.close(call)

    return true
end, 'dispatch')

mdt.register('callGps', function(src, data)
    local call = callOf(src, data)
    if not call then return false, 'gone' end

    return true, call.coords
end, 'dispatch')

---Officers on duty as the Units tab and the map show them.
---@return table[]
local function unitList()
    local list = {}

    for src, unit in pairs(roster.all()) do
        local coords = GetEntityCoords(GetPlayerPed(src))
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)

        list[#list + 1] = {
            id = src,
            name = unit.name,
            callsign = unit.callsign,
            grade = police.grade(src),
            status = unit.status,
            call = unit.call,
            since = unit.since,
            vehicle = vehicle ~= 0 and GetVehicleNumberPlateText(vehicle):match('^%s*(.-)%s*$') or nil,
            x = coords.x,
            y = coords.y,
        }
    end

    table.sort(list, function(a, b) return (a.callsign or a.name) < (b.callsign or b.name) end)

    return list
end

mdt.register('units', function()
    return true, unitList()
end, 'app')

mdt.register('setStatus', function(src, data)
    return roster.setStatus(src, data.status), nil
end, 'app')

mdt.register('setCallsign', function(src, data)
    local callsign = police.clean(data.callsign, 6):upper()
    if not callsign:match('^[%w%-]+$') then return false, 'invalid' end

    roster.setCallsign(src, callsign)

    return true
end, 'app')

mdt.register('map', function()
    local calls, anklets = {}, {}

    for _, call in ipairs(dispatch.list()) do
        calls[#calls + 1] = { id = call.id, code = call.code, title = call.title, priority = call.priority, x = call.coords.x, y = call.coords.y }
    end

    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData.metadata.tracker then
            local coords = GetEntityCoords(GetPlayerPed(src))
            anklets[#anklets + 1] = { name = police.fullName(player), citizenid = player.PlayerData.citizenid, x = coords.x, y = coords.y }
        end
    end

    return true, { units = unitList(), calls = calls, anklets = anklets }
end, 'app')
