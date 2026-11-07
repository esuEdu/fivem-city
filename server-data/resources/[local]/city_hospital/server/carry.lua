-- Carrying a downed body (to move it away before /finalizado, or to a car). Only downed players can be carried.
local settings = require 'server.config'
local state = require 'server.state'

local carrying = {} -- carrier -> carried
local carriedBy = {} -- carried -> carrier

---@param carrier integer
local function stop(carrier)
    local carried = carrying[carrier]
    if not carried then return end

    carrying[carrier], carriedBy[carried] = nil, nil

    TriggerClientEvent('city_hospital:client:carryStop', carrier)
    TriggerClientEvent('city_hospital:client:carryStop', carried)
end

lib.callback.register('city_hospital:carry', function(source, target)
    local src = source

    if type(target) ~= 'number' or target == src or not GetPlayerName(target) then return false end
    if state.down(src) or carrying[src] or carriedBy[src] then return false end
    if not state.down(target) or carriedBy[target] or carrying[target] then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > settings.ranges.interact then return false end

    carrying[src], carriedBy[target] = target, src

    TriggerClientEvent('city_hospital:client:beCarried', target, src)

    return true
end)

lib.callback.register('city_hospital:drop', function(source)
    stop(source)
    return true
end)

-- Getting up (revived, respawned) or leaving ends it from either side
local function release(src)
    if carrying[src] then stop(src) end
    if carriedBy[src] then stop(carriedBy[src]) end
end

state.onUp(release)

AddEventHandler('playerDropped', function()
    release(source)
end)
