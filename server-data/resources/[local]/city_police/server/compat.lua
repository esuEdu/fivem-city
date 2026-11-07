-- qbx_police's events that vendored scripts still fire (robberies, drug selling, car theft): they become calls.
-- See docs/city-police.md.

local dispatch = require 'server.dispatch'
local police = require 'server.police'

---@type table<integer, integer> player -> os.time of their last alert
local lastAlert = {}
local ALERT_COOLDOWN = 20

---@param text unknown
---@param src integer
local function alertFrom(text, src)
    local now = os.time()
    if lastAlert[src] and now - lastAlert[src] < ALERT_COOLDOWN then return end

    lastAlert[src] = now

    dispatch.add({
        kind = 'alert',
        code = '10-90',
        title = type(text) == 'string' and text ~= '' and text or locale('call_suspicious'),
        coords = GetEntityCoords(GetPlayerPed(src)),
    })
end

-- From a server script: TriggerEvent('police:server:policeAlert', text, camId, playerSource)
-- From a client (qbx_storerobbery, qbx_vehiclekeys): TriggerServerEvent('police:server:policeAlert', text)
RegisterNetEvent('police:server:policeAlert', function(text, _, playerSource)
    local src = source

    if src == '' or src == nil or src == 0 then
        -- Fired on the server by another resource
        playerSource = math.tointeger(playerSource)
        if playerSource and GetPlayerName(playerSource) then alertFrom(text, playerSource) end
        return
    end

    alertFrom(text, src)
end)

AddEventHandler('playerDropped', function()
    lastAlert[source] = nil
end)

-- The officer panic button (radial menu "Emergency" fires police:client:SendPoliceEmergencyAlert on the client)
RegisterNetEvent('city_police:server:panic', function()
    local src = source
    if not police.onDuty(src) then return end

    local now = os.time()
    if lastAlert[src] and now - lastAlert[src] < ALERT_COOLDOWN then return end
    lastAlert[src] = now

    dispatch.add({
        kind = 'panic',
        code = '10-99',
        title = locale('call_panic', police.name(src)),
        coords = GetEntityCoords(GetPlayerPed(src)),
        priority = 2,
    })
end)
