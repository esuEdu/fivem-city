-- Automatic calls: shots fired in town (from the shot reports server/evidence.lua already gets) and an officer on duty
-- going down (qbx_medical's death state bag, watched on the server).

local police = require 'server.police'
local dispatch = require 'server.dispatch'
local settings = require 'server.config'
local medical = require '@qbx_medical.config.shared'

local alerts = {}

local SHOTS = settings.shots
local ALIVE = medical.deathState.ALIVE

---@type table<integer, integer> shooter -> last call (ms)
local lastShotCall = {}
---@type table<integer, true> officers on duty who are down
local downed = {}

---@param coords vector3
---@return boolean
local function inTown(coords)
    for _, area in ipairs(SHOTS.areas) do
        if #(coords - area.coords) <= area.radius then return true end
    end

    return false
end

---@param weapon table city_inventory weapon (metadata.components = attachment item names)
---@return boolean
local function suppressed(weapon)
    for _, component in ipairs(weapon.metadata.components or {}) do
        if SHOTS.suppressors[component] then return true end
    end

    return false
end

---A reported shot (at most one per Config.Evidence.casingEvery per shooter) may become a call.
---@param src integer
---@param coords vector3
---@param weapon table
function alerts.shot(src, coords, weapon)
    if police.onDuty(src) or not inTown(coords) then return end

    local now = GetGameTimer()
    if lastShotCall[src] and now - lastShotCall[src] < SHOTS.cooldown * 1000 then return end

    if suppressed(weapon) and math.random() >= SHOTS.suppressedChance then return end

    lastShotCall[src] = now

    dispatch.add({
        kind = 'alert',
        code = '10-71',
        title = locale('alert_shots'),
        text = locale('alert_shots_text'),
        coords = coords,
    })
end

AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    if value == ALIVE or value == nil then
        downed[src] = nil
        return
    end

    if downed[src] or not police.onDuty(src) then return end
    downed[src] = true

    local unit = exports.qbx_core:GetPlayer(src) and police.name(src) or '?'

    dispatch.add({
        kind = 'panic',
        code = '10-99',
        title = locale('alert_officer_down'),
        text = unit,
        coords = GetEntityCoords(GetPlayerPed(src)),
        priority = 2,
    })
end)

AddEventHandler('playerDropped', function()
    lastShotCall[source] = nil
    downed[source] = nil
end)

return alerts
