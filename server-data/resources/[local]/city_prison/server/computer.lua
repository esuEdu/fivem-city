-- The prison computer at the front desk: on-duty police see who is inside or wanted for escaping, change time, release
-- and look through the log. Every action checks the officer's grade (Config.ComputerGrades) and that they are there.

local settings = require 'server.config'
local util = require 'server.util'
local inmates = require 'server.inmates'
local db = require 'server.db'

local RANGE = 4.0

local function officer(src, action)
    local grade = util.policeGrade(src)
    if not grade or grade < (Config.ComputerGrades[action] or 99) then return end
    if not util.near(src, Config.Computer.coords, RANGE) then return end

    local player = exports.qbx_core:GetPlayer(src)
    return player and util.fullName(player)
end

local function list()
    local result = {}

    for citizenid, row in pairs(inmates.all()) do
        local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)

        result[#result + 1] = {
            citizenid = citizenid,
            name = row.name,
            status = row.status,
            months = row.months,
            original = row.original,
            reduced = row.reduced,
            owed = row.owed,
            officer = row.officer,
            since = row.since,
            online = player ~= nil,
        }
    end

    table.sort(result, function(a, b) return a.since > b.since end)

    return result
end

local function grades(src)
    local grade = util.policeGrade(src) or -1
    local allowed = {}

    for action, needed in pairs(Config.ComputerGrades) do allowed[action] = grade >= needed end

    return allowed
end

local actions = {}

function actions.list(src)
    return true, { inmates = list(), history = db.history(settings.historyLimit), allowed = grades(src) }
end

function actions.setTime(_, data, name)
    local months = math.tointeger(data.months)
    if type(data.citizenid) ~= 'string' or not months or months < 0 or months > settings.maxMonths then return false, 'invalid' end

    return inmates.setTime(data.citizenid, months, name), 'not_found'
end

function actions.release(_, data, name)
    if type(data.citizenid) ~= 'string' then return false, 'invalid' end

    return inmates.setTime(data.citizenid, 0, name), 'not_found'
end

function actions.clearEscape(_, data, name)
    if type(data.citizenid) ~= 'string' then return false, 'invalid' end

    return inmates.clearEscape(data.citizenid, name), 'not_found'
end

local NEEDS = { list = 'view', setTime = 'setTime', release = 'release', clearEscape = 'clearEscape' }

lib.callback.register('city_prison:computer', function(source, action, data)
    local src = source
    local needs = type(action) == 'string' and NEEDS[action]
    if not needs then return false, 'invalid' end
    if util.throttled(src, 'computer', settings.computerThrottle) then return false, 'busy' end

    local name = officer(src, needs)
    if not name then
        util.warn(src, ('used the prison computer (%s) without access'):format(action))
        return false, 'no_access'
    end

    local ok, result = actions[action](src, type(data) == 'table' and data or {}, name)
    if ok and action ~= 'list' then return actions.list(src) end

    return ok, result
end)
