-- Sentences: going in (from city_police), the minute tick, escapes, the release desk and the exports.
lib.locale()

local settings = require 'server.config'
local util = require 'server.util'
local inmates = require 'server.inmates'
local belongings = require 'server.belongings'

local DESK_RANGE = 5.0

---Sends a player to prison. city_police calls this when an arrest is made in the MDT.
---@param src integer
---@param months integer
---@param officer? string
---@return boolean
exports('Jail', function(src, months, officer)
    months = math.tointeger(months)
    if type(src) ~= 'number' or not months or months < 1 then return false end

    return inmates.jail(src, months, officer)
end)

---@param src integer
---@return boolean serving and inside the walls
exports('IsJailed', function(src)
    return inmates.isInside(src)
end)

---city_hospital: an inmate who is down wakes up in the prison infirmary instead of the hospital. true = handled.
---@param src integer
---@return boolean
exports('Respawn', function(src)
    if not inmates.isInside(src) then return false end

    exports.qbx_medical:Revive(src)
    exports.qbx_medical:Heal(src)
    TriggerClientEvent('city_prison:client:infirmary', src)

    return true
end)

-- The release desk: out once the time is served
lib.callback.register('city_prison:release', function(source)
    local src = source
    if util.throttled(src, 'desk', 2) then return false end
    if not util.near(src, Config.Desk.coords, DESK_RANGE) then return false, 'too_far' end

    return inmates.release(src)
end)

-- The release desk, later: belongings that didn't fit, or left behind
lib.callback.register('city_prison:collect', function(source)
    local src = source
    if util.throttled(src, 'desk', 2) then return false end
    if not util.near(src, Config.Desk.coords, DESK_RANGE) then return false, 'too_far' end
    if inmates.serving(src) then return false, 'serving' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    if belongings.count(player.PlayerData.citizenid) == 0 then return false, 'empty' end

    local all = belongings.giveBack(src, player.PlayerData.citizenid)

    return true, not all and 'partial' or nil
end)

-- Inmates can't clock in
AddEventHandler('QBCore:Server:SetDuty', function(src, onDuty)
    if not onDuty or not inmates.isInside(src) then return end

    exports.qbx_core:SetJobDuty(src, false)
    util.notify(src, 'notify_no_duty', 'error')
end)

-- qbx_core's client fires this once the character has spawned (a net event, so it must be registered as one)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    -- qbx_core's own handler sets isLoggedIn first; give it a moment
    SetTimeout(1000, function() inmates.loaded(src) end)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    inmates.dropped(src)
end)

AddEventHandler('playerDropped', function()
    inmates.dropped(source)
end)

MySQL.ready(function()
    inmates.load()
    inmates.resume()

    CreateThread(function()
        while true do
            Wait(settings.secondsPerMonth * 1000)
            inmates.tick()
        end
    end)

    CreateThread(function()
        while true do
            Wait(settings.escapeCheck * 1000)
            inmates.checkEscapes()
        end
    end)
end)
