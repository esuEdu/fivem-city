-- Who is serving or owing time. Rows live in memory (loaded on start) and are written on every change; the minute tick
-- writes all changed months in one batch. inside[src] = the time an online inmate was put inside the walls.

local db = require 'server.db'
local settings = require 'server.config'
local util = require 'server.util'
local belongings = require 'server.belongings'

local inmates = {}

---@type table<string, table> citizenid -> row
local rows = {}
---@type table<integer, integer> src -> os.time() when put inside
local inside = {}

---Creates the tables and reads the rows (once, at start)
function inmates.load()
    db.init()
    rows = db.loadAll()
end

local function citizenidOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid, player
end

---@param src integer
---@return table? row of an online inmate who is serving
function inmates.serving(src)
    local citizenid = citizenidOf(src)
    local row = citizenid and rows[citizenid]

    return row and row.status == 'serving' and row or nil
end

---@param src integer
---@return boolean
function inmates.isInside(src)
    return inside[src] ~= nil
end

---@return table<integer, integer>
function inmates.inside()
    return inside
end

---@param citizenid string
---@return table?
function inmates.row(citizenid)
    return rows[citizenid]
end

---@return table<string, table>
function inmates.all()
    return rows
end

-- Tells the inmate's screen the time left, and keeps qbx_core's injail field in step for other scripts
local function sendTime(src, row)
    TriggerClientEvent('city_prison:client:time', src, row.months)
    exports.qbx_core:SetMetadata(src, 'injail', row.months)
end

-- Puts an online inmate inside: teleport (spawn = nil when they are already there, after a restart), counter, zones
local function putInside(src, row, teleport)
    inside[src] = os.time()
    Player(src).state:set('inPrison', true, true)

    local player = exports.qbx_core:GetPlayer(src)
    if player and player.PlayerData.job.onduty then exports.qbx_core:SetJobDuty(src, false) end

    TriggerClientEvent('city_prison:client:enter', src, teleport and math.random(#Config.Spawns) or nil, row.months)
    exports.qbx_core:SetMetadata(src, 'injail', row.months)
end

local function takeOut(src)
    inside[src] = nil
    TriggerEvent('city_prison:server:left', src)
    Player(src).state:set('inPrison', false, true)
    exports.qbx_core:SetMetadata(src, 'injail', 0)
end

---Sends a player to prison for months (plus any escape debt). Called by city_police when an arrest is made.
---@param src integer
---@param months integer
---@param officer? string
---@return boolean
function inmates.jail(src, months, officer)
    local citizenid, player = citizenidOf(src)
    if not citizenid or not player or months < 1 then return false end

    local row = rows[citizenid]
    local total = months

    if row then
        -- Owed from an escape, or more time while already inside
        total = total + row.owed + (row.status == 'serving' and row.months or 0)
    end

    total = math.min(total, settings.maxMonths)

    local alreadyInside = row and row.status == 'serving' and inside[src]

    row = {
        citizenid = citizenid,
        name = util.fullName(player),
        status = 'serving',
        months = total,
        original = total,
        reduced = 0,
        owed = 0,
        officer = type(officer) == 'string' and officer:sub(1, 100) or nil,
        since = os.time(),
    }
    rows[citizenid] = row
    db.save(row)
    db.log(citizenid, row.name, 'jailed', total, row.officer)

    if alreadyInside then
        sendTime(src, row)
        return true
    end

    if GetResourceState('city_police') == 'started' then exports.city_police:SetCuffed(src, false) end

    local seized = belongings.confiscate(src, citizenid)
    if seized > 0 then util.notify(src, 'notify_seized', 'error') end

    putInside(src, row, true)
    lib.print.info(('city_prison: %s (%s) jailed for %d months'):format(row.name, citizenid, total))

    return true
end

---Takes months off (prison jobs), never past the cap. Returns the months actually taken.
---@param src integer
---@param months integer
---@return integer
function inmates.reduce(src, months)
    local row = inmates.serving(src)
    if not row or row.months <= 0 then return 0 end

    local room = math.floor(row.original * settings.reduceCap) - row.reduced
    local taken = math.max(0, math.min(months, room, row.months))
    if taken == 0 then return 0 end

    row.months = row.months - taken
    row.reduced = row.reduced + taken
    db.save(row)
    sendTime(src, row)

    if row.months == 0 then inmates.release(src) end

    return taken
end

---Changes the time left (prison computer). Works offline too.
---@param citizenid string
---@param months integer
---@param actor string
function inmates.setTime(citizenid, months, actor)
    local row = rows[citizenid]
    if not row or row.status ~= 'serving' then return false end

    row.months = math.max(0, math.min(months, settings.maxMonths))
    row.original = math.max(row.original, row.months)
    db.save(row)
    db.log(citizenid, row.name, 'set_time', row.months, actor)

    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    local src = player and player.PlayerData.source

    if src then
        sendTime(src, row)

        if row.months == 0 then
            util.notify(src, 'notify_released_by_police', 'inform')
            inmates.release(src)
        else
            util.notify(src, 'notify_time_changed', 'inform', row.months)
        end
    end

    return true
end

---Lets an inmate out once the time is served (automatically, or at the desk). Gives belongings back.
---@param src integer
---@return boolean ok
---@return string? reason
function inmates.release(src)
    local row = inmates.serving(src)
    if not row then return false, 'not_inmate' end
    if row.months > 0 then return false, 'time_left' end

    rows[row.citizenid] = nil
    db.delete(row.citizenid)
    db.log(row.citizenid, row.name, 'released', row.original)

    belongings.clearPrisonItems(src)
    local all = belongings.giveBack(src, row.citizenid)

    takeOut(src)
    TriggerClientEvent('city_prison:client:released', src)
    util.notify(src, all and 'notify_belongings_back' or 'notify_belongings_partial', all and 'success' or 'error')

    return true
end

---An inmate got out of the circle: owes the time left times the multiplier, wanted on the MDT
---@param src integer
function inmates.escape(src)
    local row = inmates.serving(src)
    if not row then return end

    -- Time already served: walking out is not an escape, just a release
    if row.months == 0 then return inmates.release(src) end

    takeOut(src)
    TriggerClientEvent('city_prison:client:escaped', src)

    row.owed = math.min(math.ceil(row.months * settings.escapeMultiplier), settings.maxMonths)
    row.months = 0
    row.status = 'escaped'
    db.save(row)
    db.log(row.citizenid, row.name, 'escaped', row.owed)

    util.notify(src, 'notify_escaped', 'error')
    lib.print.info(('city_prison: %s (%s) escaped, owes %d months'):format(row.name, row.citizenid, row.owed))

    if GetResourceState('city_police') ~= 'started' then return end

    exports.city_police:Alert({
        title = locale('alert_escape_title'),
        text = locale('alert_escape_text', row.name),
        coords = Config.Prison.center,
        code = '10-98',
        priority = 2,
    })

    exports.city_police:IssueWarrant({
        citizenid = row.citizenid,
        name = row.name,
        reason = locale('warrant_reason', row.owed),
        issuedBy = Config.Prison.label,
        days = settings.warrantDays,
    })
end

---Prison computer: forgets an escape debt
---@param citizenid string
---@param actor string
function inmates.clearEscape(citizenid, actor)
    local row = rows[citizenid]
    if not row or row.status ~= 'escaped' then return false end

    rows[citizenid] = nil
    db.delete(citizenid)
    db.log(citizenid, row.name, 'cleared', row.owed, actor)

    return true
end

-- Logging in while serving: straight back inside
function inmates.loaded(src)
    local row = inmates.serving(src)
    if not row then return end

    if row.months == 0 then return inmates.release(src) end
    putInside(src, row, true)
end

-- Resource restart: whoever is online and serving carries on where they are (the escape check catches the rest)
function inmates.resume()
    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        local row = inmates.serving(src)

        if row and row.months == 0 then
            inmates.release(src)
        elseif row then
            putInside(src, row, false)
        end
    end
end

function inmates.dropped(src)
    inside[src] = nil
end

-- One month per minute for inmates online and inside
function inmates.tick()
    local changed = {}
    local done = {}

    for src in pairs(inside) do
        local row = inmates.serving(src)

        if row and row.months > 0 then
            row.months = row.months - 1
            changed[#changed + 1] = row
            sendTime(src, row)

            if row.months == 0 then done[#done + 1] = src end
        end
    end

    db.saveMonths(changed)

    -- Time served: straight out with the belongings, no trip to the desk
    for _, src in ipairs(done) do inmates.release(src) end
end

-- Anyone serving who is outside the circle (after the grace period) has escaped
function inmates.checkEscapes()
    local now = os.time()
    local found = {}

    for src, since in pairs(inside) do
        if now - since > settings.entryGrace and not util.near(src, Config.Prison.center, Config.Prison.radius) then
            found[#found + 1] = src
        end
    end

    for _, src in ipairs(found) do
        if Config.Features.escape then
            inmates.escape(src)
        else
            local spawn = Config.Spawns[math.random(#Config.Spawns)]
            SetEntityCoords(GetPlayerPed(src), spawn.x, spawn.y, spawn.z, false, false, false, false)
            inside[src] = now
            util.notify(src, 'notify_brought_back', 'error')
        end
    end
end

return inmates
