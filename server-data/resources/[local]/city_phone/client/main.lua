-- Opening and closing the phone, holding it in the hand, the game clock on the status bar and the settings.
local theme = require '@city_ui.theme'
local apps = require 'client.apps'
local hold = require 'client.hold'

local CLOCK_MS = 2000

local isOpen = false
local profile

local function clock()
    return {
        hours = GetClockHours(),
        minutes = GetClockMinutes(),
        weekday = GetClockDayOfWeek(),
        day = GetClockDayOfMonth(),
        month = GetClockMonth(),
        year = GetClockYear(),
    }
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    hold.stop()
end

local function open()
    if isOpen or LocalPlayer.state.isDead or IsPauseMenuActive() then return end

    profile = profile or lib.callback.await('city_phone:profile', false)
    if not profile then return end

    isOpen = true
    SendNUIMessage({ action = 'open', profile = profile, apps = apps.list(), clock = clock() })
    SetNuiFocus(true, true)
    hold.start()

    -- The status bar clock follows the game's clock, only while the phone is open
    CreateThread(function()
        while isOpen do
            Wait(CLOCK_MS)
            if isOpen then SendNUIMessage({ action = 'clock', clock = clock() }) end
        end
    end)
end

RegisterNetEvent('city_phone:client:toggle', function()
    if GetInvokingResource() then return end
    if isOpen then close() else open() end
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ theme = theme })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

RegisterNUICallback('saveSetting', function(data, cb)
    local ok = lib.callback.await('city_phone:saveSetting', false, data.key, data.value)

    if ok and profile then profile.settings[data.key] = data.value end

    cb(ok == true)
end)

-- Losing the phone item or going down closes it
AddEventHandler('ox_inventory:itemCount', function(name, count)
    if name == Config.Item and count < 1 then close() end
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then close() end
end)

-- A new character has another number and settings
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    profile = nil
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    close()
    profile = nil
end)

---@return boolean
exports('IsOpen', function() return isOpen end)
exports('Close', close)

---The settings the phone uses now (theme, language, font, ...), for apps that draw outside the phone
exports('GetSettings', function() return profile and profile.settings end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if isOpen then SetNuiFocus(false, false) end
    hold.stop()
end)
