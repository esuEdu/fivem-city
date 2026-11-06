-- Watching a player: the staff member's ped hides below the target (so the target stays streamed in) while the
-- camera follows them. Backspace stops and puts the staff member back where they were.

local selfTools = require 'client.self'

local STOP_KEY = 177 -- Backspace / Esc (frontend cancel)
local BELOW = 8.0

local spectate = {}

local watching = nil
local returnTo = nil

---@param ped integer
---@param hidden boolean
local function hide(ped, hidden)
    FreezeEntityPosition(ped, hidden)
    SetEntityCollision(ped, not hidden, not hidden)
    SetEntityVisible(ped, not hidden and not selfTools.get('invisible'), false)
    SetEntityInvincible(ped, hidden or selfTools.get('godmode'))
end

function spectate.stop()
    if not watching then return end

    watching = nil
    NetworkSetInSpectatorMode(false, cache.ped)
    lib.hideTextUI()

    local ped = cache.ped
    SetEntityCoords(ped, returnTo.x, returnTo.y, returnTo.z, false, false, false, false)
    hide(ped, false)
    returnTo = nil

    lib.callback.await('city_staff:stopSpectate', false)
end

---@param info { target: integer, coords: vector3 }
function spectate.start(info)
    if watching then spectate.stop() end
    if selfTools.get('noclip') then selfTools.set('noclip', false) end

    local ped = cache.ped
    watching = info.target
    returnTo = GetEntityCoords(ped)

    hide(ped, true)
    SetEntityCoords(ped, info.coords.x, info.coords.y, info.coords.z - BELOW, false, false, false, false)
    lib.showTextUI(locale('spectate_hint'))

    CreateThread(function()
        local target = info.target
        local started = false
        local nextFollow = 0
        local giveUpAt = GetGameTimer() + 10000

        while watching == target do
            local player = GetPlayerFromServerId(target)
            local targetPed = player ~= -1 and GetPlayerPed(player) or 0

            if targetPed ~= 0 and DoesEntityExist(targetPed) then
                if not started then
                    NetworkSetInSpectatorMode(true, targetPed)
                    started = true
                end

                if GetGameTimer() > nextFollow then
                    local coords = GetEntityCoords(targetPed)
                    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - BELOW, false, false, false, false)
                    nextFollow = GetGameTimer() + 1000
                end
            elseif started or GetGameTimer() > giveUpAt then
                -- The target left the server, or never came into range
                break
            end

            if IsControlJustPressed(0, STOP_KEY) or IsDisabledControlJustPressed(0, STOP_KEY) then break end

            Wait(0)
        end

        if watching == target then spectate.stop() end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not watching then return end

    NetworkSetInSpectatorMode(false, cache.ped)
    lib.hideTextUI()
    SetEntityCoords(cache.ped, returnTo.x, returnTo.y, returnTo.z, false, false, false, false)
    hide(cache.ped, false)
end)

return spectate
