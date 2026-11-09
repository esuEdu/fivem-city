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

-- While the phone is open the game still gets the keys (walking); only the controls in Config.BlockedControls are off
local function blockControls()
    local controls = Config.BlockedControls

    while isOpen do
        for i = 1, #controls do DisableControlAction(0, controls[i], true) end
        Wait(0)
    end
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    hold.stop()
end

local function open()
    if isOpen or LocalPlayer.state.isDead or IsPauseMenuActive() then return end

    profile = profile or lib.callback.await('city_phone:profile', false)
    if not profile then return end

    apps.setBurner(profile.burner)
    isOpen = true
    SendNUIMessage({ action = 'open', profile = profile, apps = apps.list(), clock = clock() })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    CreateThread(blockControls)
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

-- burner: opened from a burner phone (another number, fewer apps) or from the player's own phone
RegisterNetEvent('city_phone:client:toggle', function(burner)
    if GetInvokingResource() then return end

    -- Switching between the own phone and a burner: read the profile again
    if profile and (profile.burner == true) ~= (burner == true) then
        close()
        profile = nil
    end

    if isOpen then close() else open() end
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ theme = theme })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

-- A text field on the phone has focus: the keys write instead of moving the player
RegisterNUICallback('typing', function(data, cb)
    if isOpen then SetNuiFocusKeepInput(data.on ~= true) end
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
    if count > 0 then return end

    local using = profile and profile.burner and Config.BurnerItem or Config.Item
    if name == using then close() end
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

    local using = LocalPlayer.state.phoneBurner and Config.BurnerItem or Config.Item
    if exports.city_inventory:GetItemCount(using) < 1 then return false end

    -- An incoming call on the other phone than the profile we have
    if profile and (profile.burner == true) ~= (LocalPlayer.state.phoneBurner ~= nil) then profile = nil end

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

    if isOpen then
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
    hold.stop()
end)
