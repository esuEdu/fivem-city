-- Opening and closing the phone, holding it in the hand, the game clock on the status bar and the settings.
local theme = require '@city_ui.theme'
local apps = require 'client.apps'
local hold = require 'client.hold'

local CLOCK_MS = 2000

local isOpen = false
local profile
local wallpaper = { id = 0, data = nil }

-- A photo wallpaper comes from the Photos app (if it is installed); fetched once and kept
local function loadWallpaper()
    local id = profile and profile.settings.wallpaperPhoto or 0

    if id > 0 and wallpaper.id ~= id and GetResourceState('city_phone_photos') == 'started' then
        wallpaper = { id = id, data = lib.callback.await('city_phone_photos:photo', false, id) }
    end

    SendNUIMessage({ action = 'wallpaperImage', data = id > 0 and wallpaper.id == id and wallpaper.data or false })
end

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
    CreateThread(loadWallpaper)

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
    if ok and data.key == 'wallpaperPhoto' then CreateThread(loadWallpaper) end

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

---Opens the phone from code (an incoming call). Needs the phone item; returns whether it opened.
exports('Open', function()
    if isOpen then return true end
    if exports.city_inventory:GetItemCount(Config.Item) < 1 then return false end

    open()
    return isOpen
end)

---Uses one of the player's photos as the wallpaper (the Photos app); the server checks the value again
exports('SetWallpaperPhoto', function(id)
    if not profile or not lib.callback.await('city_phone:saveSetting', false, 'wallpaperPhoto', id) then return false end

    profile.settings.wallpaperPhoto = id
    SendNUIMessage({ action = 'setting', key = 'wallpaperPhoto', value = id })
    loadWallpaper()
    return true
end)

---The settings the phone uses now (theme, language, font, ...), for apps that draw outside the phone
exports('GetSettings', function() return profile and profile.settings end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if isOpen then SetNuiFocus(false, false) end
    hold.stop()
end)
