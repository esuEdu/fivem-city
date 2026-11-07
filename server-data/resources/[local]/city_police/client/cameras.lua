-- Security cameras, opened from the MDT: a scripted camera at the spot, ← / → change camera, A / D turn the ones that
-- turn, Backspace leaves. Robberies cut cameras (qbx_bankrobbery fires police:client:SetCamera and friends).

local job = require 'client.job'
local theme = require '@city_ui.theme'

local online = {}
for index in ipairs(Config.Cameras) do online[index] = true end

local camera = nil
local current = nil
local KEYS = { previous = 174, next = 175, left = 34, right = 35, leave = 177 }

local function clockText()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

---@param index integer
local function show(index)
    local spot = Config.Cameras[index]
    current = index

    if camera then DestroyCam(camera, false) end

    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, spot.coords.x, spot.coords.y, spot.coords.z)
    SetCamRot(camera, spot.rot.x, spot.rot.y, spot.rot.z, 2)
    SetFocusArea(spot.coords.x, spot.coords.y, spot.coords.z, 0.0, 0.0, 0.0)
    RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(1.5)

    SendNUIMessage({ action = 'camera', theme = theme, label = spot.label, index = index, total = #Config.Cameras, online = online[index], time = clockText(),
        labels = { offline = locale('camera_offline'), help = locale('camera_help') } })
end

local function leave()
    if not camera then return end

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    DestroyCam(camera, false)
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()
    ClearFocus()
    FreezeEntityPosition(cache.ped, false)
    camera, current = nil, nil

    SendNUIMessage({ action = 'cameraOff' })
    DoScreenFadeIn(250)
end

---@param index integer
local function open(index)
    if camera or not Config.Cameras[index] or not job.onDuty() then return end

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    FreezeEntityPosition(cache.ped, true)
    show(index)
    DoScreenFadeIn(250)

    CreateThread(function()
        while camera do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk

            if IsDisabledControlJustPressed(0, KEYS.leave) or not job.onDuty() then
                leave()
            elseif IsDisabledControlJustPressed(0, KEYS.next) then
                show(current % #Config.Cameras + 1)
            elseif IsDisabledControlJustPressed(0, KEYS.previous) then
                show((current - 2) % #Config.Cameras + 1)
            elseif Config.Cameras[current].rotate then
                local turn = (IsDisabledControlPressed(0, KEYS.left) and 0.4 or 0) - (IsDisabledControlPressed(0, KEYS.right) and 0.4 or 0)
                if turn ~= 0 then
                    local rot = GetCamRot(camera, 2)
                    SetCamRot(camera, rot.x, rot.y, rot.z + turn, 2)
                end
            end

            Wait(0)
        end
    end)
end

RegisterNetEvent('police:client:SetCamera', function(key, isOnline)
    if GetInvokingResource() then return end

    local list = type(key) == 'table' and key or { key }
    for _, index in ipairs(list) do
        if online[index] ~= nil then online[index] = isOnline == true end
    end

    if current then show(current) end
end)

RegisterNetEvent('police:client:DisableAllCameras', function()
    if GetInvokingResource() then return end
    for index in pairs(online) do online[index] = false end
    if current then show(current) end
end)

RegisterNetEvent('police:client:EnableAllCameras', function()
    if GetInvokingResource() then return end
    for index in pairs(online) do online[index] = true end
    if current then show(current) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not camera then return end

    DestroyCam(camera, false)
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()
    ClearFocus()
    FreezeEntityPosition(cache.ped, false)
end)

-- Loaded by client/mdt.lua (the Cameras tab opens them and shows which work)
return {
    open = open,
    states = function() return online end,
}
