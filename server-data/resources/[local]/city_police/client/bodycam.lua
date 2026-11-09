-- Watching another unit's bodycam from the MDT: like the Staff app's spectate, the viewer's ped hides below the unit
-- (so they stay streamed in) while the game camera follows them. Backspace leaves and puts the viewer back.

local job = require 'client.job'
local theme = require '@city_ui.theme'

local STOP_KEY = 177
local BELOW = 8.0

local watching = nil
local returnTo = nil

---@param hidden boolean
local function hide(hidden)
    local ped = cache.ped

    FreezeEntityPosition(ped, hidden)
    SetEntityCollision(ped, not hidden, not hidden)
    SetEntityVisible(ped, not hidden, false)
    SetEntityInvincible(ped, hidden)
end

local function stop()
    if not watching then return end

    watching = nil
    NetworkSetInSpectatorMode(false, cache.ped)
    SendNUIMessage({ action = 'cameraOff' })

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoords(cache.ped, returnTo.x, returnTo.y, returnTo.z, false, false, false, false)
    hide(false)
    returnTo = nil

    DoScreenFadeIn(250)
end

---@param info { target: integer, coords: vector3, label: string }
local function start(info)
    if watching or not job.onDuty() then return end

    watching = info.target
    returnTo = GetEntityCoords(cache.ped)

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    hide(true)
    SetEntityCoords(cache.ped, info.coords.x, info.coords.y, info.coords.z - BELOW, false, false, false, false)
    SendNUIMessage({ action = 'bodycam', theme = theme, label = info.label, help = locale('bodycam_help') })

    CreateThread(function()
        local target = info.target
        local started = false
        local nextFollow = 0
        local giveUpAt = GetGameTimer() + 10000

        while watching == target and job.onDuty() do
            local player = GetPlayerFromServerId(target)
            local targetPed = player ~= -1 and GetPlayerPed(player) or 0

            if targetPed ~= 0 and DoesEntityExist(targetPed) then
                if not started then
                    NetworkSetInSpectatorMode(true, targetPed)
                    DoScreenFadeIn(250)
                    started = true
                end

                if GetGameTimer() > nextFollow then
                    local coords = GetEntityCoords(targetPed)
                    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - BELOW, false, false, false, false)
                    nextFollow = GetGameTimer() + 1000
                end
            elseif started or GetGameTimer() > giveUpAt then
                break
            end

            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk
            if IsDisabledControlJustPressed(0, STOP_KEY) then break end

            Wait(0)
        end

        if watching == target then stop() end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not watching then return end

    NetworkSetInSpectatorMode(false, cache.ped)
    SetEntityCoords(cache.ped, returnTo.x, returnTo.y, returnTo.z, false, false, false, false)
    hide(false)
    DoScreenFadeIn(0)
end)

-- Loaded by client/mdt.lua (the Units tab opens it)
return { start = start }
