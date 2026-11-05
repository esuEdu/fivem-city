local settings = require 'shared.settings'
local theme = require '@city_ui.theme'

-- The player's own wallpaper picture: kept on this computer only, never sent to the server
local KVP_WALLPAPER = 'wallpaper'

local isOpen = false
local busy = false
local prop
local deviceColor

---@type table<string, table> apps the page shows, by id
local apps = {}

---@param list? table[]
local function indexApps(list)
    apps = {}

    for _, app in ipairs(list or {}) do
        apps[app.id] = app
    end
end

---@param reason? string
local function notifyFailure(reason)
    local key = ('error_%s'):format(reason)
    local message = locale(key)

    lib.notify({ description = message ~= key and message or locale('error_generic'), type = 'error' })
end

---@return boolean
local function canUse()
    return LocalPlayer.state.isLoggedIn
        and not IsPedDeadOrDying(cache.ped, true)
        and not IsPedCuffed(cache.ped)
        and not IsPauseMenuActive()
        -- Not while driving
        and not (cache.vehicle and cache.seat == -1)
end

---@param id? string a Config.DeviceColors id
---@return table color
local function colorFor(id)
    return settings.deviceColor(id) or Config.DeviceColors[1]
end

-- The tint is set on our prop and in a state bag, so every player paints it the same way (see the handler below)
---@param color table
local function paintProp(color)
    if not prop or not DoesEntityExist(prop) or not color.tint then return end

    SetObjectTextureVariation(prop, color.tint)
    Entity(prop).state:set('cityOsTint', color.tint, true)
end

local function startAnimation()
    local anim = Config.Animation
    local color = colorFor(deviceColor)
    local model = color.model and joaat(color.model) or Config.Prop.model

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, 49, 0, false, false, false)

    lib.requestModel(model)
    local coords = GetEntityCoords(cache.ped)
    prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(model)

    local offset, rotation = Config.Prop.offset, Config.Prop.rotation
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, Config.Prop.bone), offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)
    paintProp(color)
end

local function stopAnimation()
    StopAnimTask(cache.ped, Config.Animation.dict, Config.Animation.clip, 2.0)
    RemoveAnimDict(Config.Animation.dict)

    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

---@return { hours: integer, minutes: integer }
local function clock()
    return { hours = GetClockHours(), minutes = GetClockMinutes() }
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopAnimation()
    TriggerServerEvent('city_os:server:closed')
end

---@param slot? integer the tablet's slot, when opened by using the item
local function open(slot)
    if isOpen or busy then return end
    if not canUse() then return notifyFailure('busy') end

    busy = true
    local success, data = lib.callback.await('city_os:open', false, slot)
    busy = false

    if not success then return notifyFailure(data) end

    isOpen = true
    deviceColor = data.settings.deviceColor
    indexApps(data.apps)
    startAnimation()
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        tablet = data,
        theme = theme,
        labels = lib.getLocales(),
        wallpapers = Config.Wallpapers,
        deviceColors = Config.DeviceColors,
        customWallpaper = GetResourceKvpString(KVP_WALLPAPER) or false,
        config = { dockSize = Config.DockSize, bannerSeconds = Config.BannerSeconds, appIdleSeconds = Config.AppIdleSeconds },
        clock = clock(),
    })

    -- The in-game clock, and closing if the player gets hurt or cuffed; only while open
    CreateThread(function()
        local last = -1

        while isOpen do
            local now = clock()

            if now.minutes ~= last then
                last = now.minutes
                SendNUIMessage({ action = 'clock', clock = now })
            end

            if not canUse() then close() end

            Wait(1000)
        end
    end)
end

RegisterNetEvent('city_os:client:open', open)

-- Other players' tablets: apply the tint their owner chose
AddStateBagChangeHandler('cityOsTint', nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end

    CreateThread(function()
        -- The prop may reach this client a moment after its state bag
        for _ = 1, 20 do
            local entity = GetEntityFromStateBagName(bagName)

            if entity ~= 0 and DoesEntityExist(entity) then
                return SetObjectTextureVariation(entity, value)
            end

            Wait(100)
        end
    end)
end)

-- /tablettint (admin): tries texture variations on the tablet in hand, to fill Config.DeviceColors tints
RegisterNetEvent('city_os:client:testTint', function(tint)
    if GetInvokingResource() or type(tint) ~= 'number' then return end
    if not prop or not DoesEntityExist(prop) then return notifyFailure('no_tablet_open') end

    SetObjectTextureVariation(prop, tint)
    lib.notify({ description = locale('tint_set', tint), type = 'inform' })
end)

RegisterNetEvent('city_os:client:apps', function(list, badges)
    indexApps(list)
    if isOpen then SendNUIMessage({ action = 'apps', apps = list, badges = badges }) end
end)

RegisterNetEvent('city_os:client:notify', function(note)
    if isOpen then
        SendNUIMessage({ action = 'notify', note = note })
    elseif note.banner and not note.hidden then
        lib.notify({ title = note.appLabel, description = note.title, type = 'inform' })
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    close()
end)

RegisterNUICallback('unlock', function(data, cb)
    local success, result, extra = lib.callback.await('city_os:unlock', false, type(data) == 'table' and data.code)

    if success then indexApps(result) end

    cb({ ok = success, apps = success and result or nil, badges = success and extra or nil, reason = not success and result or nil, wait = not success and extra or nil })
end)

RegisterNUICallback('saveSettings', function(data, cb)
    local success, saved = lib.callback.await('city_os:saveSettings', false, settings.sanitize(type(data) == 'table' and data.settings))
    cb({ ok = success, settings = saved })

    -- A new device color repaints the tablet in hand, or swaps it when the color is its own model
    if not success or not isOpen or saved.deviceColor == deviceColor then return end

    local before, after = colorFor(deviceColor), colorFor(saved.deviceColor)
    deviceColor = saved.deviceColor

    if before.model ~= after.model then
        stopAnimation()
        startAnimation()
    else
        paintProp(after)
    end
end)

RegisterNUICallback('setCode', function(data, cb)
    local code = type(data) == 'table' and data.code

    cb({ ok = lib.callback.await('city_os:setCode', false, settings.isCode(code) and code or false) })
end)

RegisterNUICallback('clearNotifications', function(_, cb)
    cb({ ok = lib.callback.await('city_os:clearNotifications', false) })
end)

-- Own picture as wallpaper: saved with this computer's resource storage only
RegisterNUICallback('setWallpaper', function(data, cb)
    local url = type(data) == 'table' and data.url

    if url == false then
        DeleteResourceKvp(KVP_WALLPAPER)
        return cb({ ok = true })
    end

    if not settings.isWallpaperUrl(url) then return cb({ ok = false }) end

    SetResourceKvp(KVP_WALLPAPER, url)
    cb({ ok = true, url = url })
end)

-- Opening an app whose resource stopped shows "isn't available" instead of a blank frame
RegisterNUICallback('openApp', function(data, cb)
    local app = type(data) == 'table' and apps[data.id]

    cb({ ok = app ~= nil and GetResourceState(app.resource) == 'started' })
end)

lib.addKeybind({
    name = 'tablet',
    description = locale('keybind_open'),
    defaultKey = Config.OpenKey,
    onPressed = function()
        if isOpen then close() else open() end
    end,
})

exports('IsOpen', function()
    return isOpen
end)

exports('Close', close)

---Sends data from an app's client script to its page inside the tablet.
---@param appId string
---@param data any
exports('SendAppMessage', function(appId, data)
    local app = apps[appId]
    if not app or app.resource ~= GetInvokingResource() then return false end

    SendNUIMessage({ action = 'appMessage', app = appId, data = data })

    return true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not isOpen then return end

    SetNuiFocus(false, false)
    stopAnimation()
end)
