-- Tournaments: one at a time, from the schedule or opened by staff. Players join in the app; only catches made inside
-- the tournament's region while it runs count. The top three online at the end get the prizes.
local settings = require 'server.config'
local fish = require 'server.fish'
local levels = require 'shared.levels'
local profiles = require 'server.profiles'
local util = require 'server.util'

local tournaments = {}

local MODES = { biggest = true, count = true, weight = true }
local REGIONS = { ocean = true, deep = true, alamo = true, river = true, lake = true, canal = true }

local current
local lastResults

function tournaments.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_fishing_tournaments` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `label` VARCHAR(80) NOT NULL,
            `mode` VARCHAR(16) NOT NULL,
            `region` VARCHAR(16) NOT NULL,
            `species` VARCHAR(50) NULL,
            `started_by` VARCHAR(50) NULL,
            `started_at` INT NOT NULL,
            `ended_at` INT NOT NULL,
            `results` LONGTEXT NOT NULL
        )
    ]])

    local row = MySQL.single.await('SELECT `label`, `mode`, `results`, `ended_at` FROM `city_fishing_tournaments` ORDER BY `id` DESC LIMIT 1')
    if row then
        lastResults = { label = row.label, mode = row.mode, endedAt = row.ended_at, ranking = json.decode(row.results) or {} }
    end
end

---Checks what a schedule entry or a staff form asks for.
---@param data unknown
---@return table? clean
function tournaments.clean(data)
    if type(data) ~= 'table' then return end

    local minutes = math.tointeger(tonumber(data.minutes))
    local label = type(data.label) == 'string' and data.label:gsub('[%c<>]', ''):sub(1, 60) or ''
    local species = data.species

    if not MODES[data.mode] or not REGIONS[data.region] then return end
    if not minutes or minutes < 5 or minutes > settings.tournaments.maxMinutes then return end
    if #label < 3 then return end

    if species ~= nil and species ~= '' then
        local entry = fish.byName[species]
        if not entry or entry.kind ~= 'fish' or entry.legendary then return end
    else
        species = nil
    end

    return { label = label, mode = data.mode, region = data.region, minutes = minutes, species = species }
end

---@param data table already cleaned
---@param startedBy? string citizenid of the staff member
---@return boolean
function tournaments.start(data, startedBy)
    if current then return false end

    current = {
        label = data.label,
        mode = data.mode,
        region = data.region,
        species = data.species,
        startedBy = startedBy,
        startedAt = os.time(),
        endsAt = os.time() + data.minutes * 60,
        entries = {},
    }

    GlobalState.fishingTournament = {
        label = current.label,
        mode = current.mode,
        region = current.region,
        species = current.species and fish.byName[current.species].label or nil,
        endsAt = current.endsAt,
    }

    TriggerClientEvent('city_fishing:client:announce', -1, 'tournament_started', current.label)

    return true
end

---@param src integer
---@param citizenid string
---@return boolean ok
---@return string? reason
function tournaments.join(src, citizenid)
    if not current then return false, 'no_tournament' end
    if current.entries[citizenid] then return false, 'already_joined' end

    current.entries[citizenid] = { name = util.name(src), score = 0, at = os.time() }

    return true
end

---@param src integer
---@param citizenid string
---@param entry table fish entry
---@param size integer
---@param count integer
---@param bobber vector3
---@param region string
function tournaments.onCatch(src, citizenid, entry, size, count, bobber, region)
    local joined = current and current.entries[citizenid]
    if not joined or os.time() >= current.endsAt or region ~= current.region then return end
    if current.species and entry.name ~= current.species then return end

    local score
    if current.mode == 'biggest' then
        score = math.max(joined.score, size)
    elseif current.mode == 'count' then
        score = joined.score + count
    else
        local kg = (size / 10) ^ 3 * settings.weightFactor * count
        score = joined.score + math.floor(kg * 10 + 0.5) / 10
    end

    if score > joined.score then
        joined.score = score
        joined.at = os.time()
    end
end

---@return table[] ranking, best first
local function ranking()
    local list = {}

    if not current then return list end

    for citizenid, entry in pairs(current.entries) do
        list[#list + 1] = { citizenid = citizenid, name = entry.name, score = entry.score, at = entry.at }
    end

    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.at < b.at
    end)

    return list
end

function tournaments.finish()
    if not current then return end

    local list = ranking()
    local finished = current
    current = nil
    GlobalState.fishingTournament = nil

    local results = {}

    for place, entry in ipairs(list) do
        local prize = 0

        if place <= #settings.tournaments.prizes and entry.score > 0 then
            local player = exports.qbx_core:GetPlayerByCitizenId(entry.citizenid)
            local bonus = 1 + levels.value(profiles.get(entry.citizenid).skills, 'prizes')
            prize = math.floor(settings.tournaments.prizes[place] * bonus)

            if player then
                exports.qbx_core:AddMoney(player.PlayerData.source, 'cash', prize, 'fishing-tournament')
                util.notify(player.PlayerData.source, 'tournament_prize', 'success', place, prize)
            else
                prize = 0
            end
        end

        if place <= 10 then results[#results + 1] = { name = entry.name, score = entry.score, prize = prize } end
    end

    lastResults = { label = finished.label, mode = finished.mode, endedAt = os.time(), ranking = results }

    MySQL.insert('INSERT INTO `city_fishing_tournaments` (`label`, `mode`, `region`, `species`, `started_by`, `started_at`, `ended_at`, `results`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        finished.label, finished.mode, finished.region, finished.species, finished.startedBy, finished.startedAt, os.time(), json.encode(results),
    })

    TriggerClientEvent('city_fishing:client:announce', -1, 'tournament_ended', finished.label, results[1] and results[1].name or '-')
end

---Every minute from events.lua: end the running one, or start a scheduled one.
---@param lastStart table<string, boolean> keys already started this hour
function tournaments.tick(lastStart)
    if current then
        if os.time() >= current.endsAt then tournaments.finish() end
        return
    end

    local now = os.date('*t')

    for index, entry in ipairs(settings.tournaments.schedule) do
        local key = ('%d:%d:%d'):format(index, now.yday, now.hour)

        if entry.wday == now.wday and entry.hour == now.hour and now.min < 10 and not lastStart[key] then
            lastStart[key] = true
            local data = tournaments.clean(entry)
            if data then tournaments.start(data) end
        end
    end
end

---What the app shows: the running tournament with its ranking and whether this character joined, and the last results.
---@param citizenid string
---@return table
function tournaments.snapshot(citizenid)
    local running

    if current then
        local list = ranking()
        local top = {}
        for i = 1, math.min(10, #list) do top[i] = { name = list[i].name, score = list[i].score } end

        running = {
            label = current.label,
            mode = current.mode,
            region = current.region,
            species = current.species and fish.byName[current.species].label or nil,
            endsAt = current.endsAt,
            joined = current.entries[citizenid] ~= nil,
            ranking = top,
        }
    end

    local schedule = {}
    for _, entry in ipairs(settings.tournaments.schedule) do
        schedule[#schedule + 1] = { label = entry.label, wday = entry.wday, hour = entry.hour, mode = entry.mode, region = entry.region }
    end

    return { running = running, last = lastResults, schedule = schedule, prizes = settings.tournaments.prizes }
end

return tournaments
