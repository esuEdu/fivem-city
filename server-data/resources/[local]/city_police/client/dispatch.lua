-- Officers' side of calls: a blip, a sound and a popup on screen for each new call or radio code (the tablet shows
-- the notification too). F10 takes the newest popup (attaches to the call and sets the GPS), F11 dismisses it; each
-- goes after Config.Dispatch.popup.seconds and the oldest makes room when more than popup.max are up.

local job = require 'client.job'
local theme = require '@city_ui.theme'

local POPUP = Config.Dispatch.popup

local blips = {}

---@type { key: string, call: integer?, coords: vector3? }[] oldest first
local popups = {}
local nextKey = 0

---@param id integer
local function removeBlip(id)
    if blips[id] then RemoveBlip(blips[id]) end
    blips[id] = nil
end

---@param key string
local function removePopup(key)
    for index, popup in ipairs(popups) do
        if popup.key == key then
            table.remove(popups, index)
            SendNUIMessage({ action = 'popupOff', key = key })
            return
        end
    end
end

---@param data { call: integer?, code: string, title: string, text: string?, coords: table?, priority: integer?, kind: string }
local function showPopup(data)
    nextKey = nextKey + 1
    local key = tostring(nextKey)
    local coords = data.coords and vec3(data.coords.x, data.coords.y, data.coords.z) or nil

    popups[#popups + 1] = { key = key, call = data.call, coords = coords }
    while #popups > POPUP.max do removePopup(popups[1].key) end

    SendNUIMessage({
        action = 'popup',
        theme = theme,
        popup = {
            key = key,
            kind = data.kind,
            code = data.code,
            title = data.title,
            text = data.text,
            place = coords and job.place(coords) or nil,
            urgent = data.priority == 2,
            seconds = POPUP.seconds,
            time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        },
        labels = { header = locale('popup_header'), gps = locale('popup_gps'), dismiss = locale('popup_dismiss'), gpsKey = POPUP.gpsKey, dismissKey = POPUP.dismissKey },
    })

    SetTimeout(POPUP.seconds * 1000, function() removePopup(key) end)
end

RegisterNetEvent('city_police:client:newCall', function(call)
    if GetInvokingResource() or type(call) ~= 'table' then return end

    local style = call.kind == 'panic' and Config.Dispatch.panicBlip or Config.Dispatch.blip
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)

    SetBlipSprite(blip, style.sprite)
    SetBlipColour(blip, style.colour)
    SetBlipScale(blip, style.scale)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s · %s'):format(call.code, call.title))
    EndTextCommandSetBlipName(blip)

    removeBlip(call.id)
    blips[call.id] = blip

    SetTimeout(10000, function()
        if blips[call.id] then SetBlipFlashes(blips[call.id], false) end
    end)
    SetTimeout(Config.Dispatch.minutes * 60000, function() removeBlip(call.id) end)

    if call.priority == 2 then
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    else
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    end

    showPopup({ call = call.id, kind = call.kind, code = call.code, title = call.title, text = call.text, coords = call.coords, priority = call.priority })
end)

-- A radio code from another unit (F6 menu): a popup only, F10 points the GPS at where they sent it
RegisterNetEvent('city_police:client:radioCode', function(data)
    if GetInvokingResource() or type(data) ~= 'table' then return end

    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', true)
    showPopup({ kind = 'code', code = data.code, title = data.label, text = data.from, coords = data.coords })
end)

RegisterNetEvent('city_police:client:callClosed', function(id)
    if GetInvokingResource() then return end
    removeBlip(id)

    for _, popup in ipairs(popups) do
        if popup.call == id then return removePopup(popup.key) end
    end
end)

lib.addKeybind({
    name = 'police_call_gps',
    description = locale('key_call_gps'),
    defaultKey = POPUP.gpsKey,
    onPressed = function()
        local popup = popups[#popups]
        if not popup or not job.onDuty() then return end

        removePopup(popup.key)

        if popup.call then
            local ok, coords = lib.callback.await('city_police:mdt:callAttach', false, { id = popup.call })
            if not ok then return job.fail(coords) end
            if coords then SetNewWaypoint(coords.x + 0.0, coords.y + 0.0) end
        elseif popup.coords then
            SetNewWaypoint(popup.coords.x, popup.coords.y)
        end

        exports.qbx_core:Notify(locale('popup_gps_set'), 'success')
    end,
})

lib.addKeybind({
    name = 'police_call_dismiss',
    description = locale('key_call_dismiss'),
    defaultKey = POPUP.dismissKey,
    onPressed = function()
        local popup = popups[#popups]
        if popup then removePopup(popup.key) end
    end,
})

local function clearAll()
    for id in pairs(blips) do removeBlip(id) end
    for i = #popups, 1, -1 do removePopup(popups[i].key) end
end

AddEventHandler('city_police:client:dutyChanged', function(onDuty)
    if not onDuty then clearAll() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then clearAll() end
end)
