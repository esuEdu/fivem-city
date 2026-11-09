-- The patrol car menu (F6 in a police car, on duty): radio codes for the other units (server/radio.lua) and the
-- radar buttons. The mouse is free while it's open and the car can still be driven.

local job = require 'client.job'
local theme = require '@city_ui.theme'

local POLICE_CLASS = 18
-- Looking around and shooting while the mouse is on the menu
local BLOCKED = { 1, 2, 24, 25, 68, 69, 70, 91, 92, 106, 114, 257, 263, 331 }

local open = false
local radar = { on = false, locked = false }

local function codes()
    local list = {}
    for index, entry in ipairs(Config.RadioCodes) do
        list[index] = { index = index, code = entry.code, label = entry.label, urgent = entry.call == true }
    end
    return list
end

local CODES = codes()

local function draw()
    SendNUIMessage({
        action = 'carMenu',
        theme = theme,
        codes = CODES,
        radar = radar,
        labels = {
            title = locale('car_menu_title'), subtitle = locale('car_menu_subtitle'), radar = locale('car_menu_radar'),
            lock = locale('car_menu_lock'), codes = locale('car_menu_codes'), close = locale('radial_close'),
        },
    })
end

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'carMenuOff' })
end

local function show()
    if open or not job.onDuty() or not cache.vehicle or GetVehicleClass(cache.vehicle) ~= POLICE_CLASS then return end

    open = true
    draw()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    CreateThread(function()
        while open do
            for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
            if not cache.vehicle or not job.onDuty() then close() end
            Wait(0)
        end
    end)
end

lib.addKeybind({
    name = 'police_car_menu',
    description = locale('key_car_menu'),
    defaultKey = Config.Keys.carMenu,
    onPressed = function()
        if open then close() else show() end
    end,
})

RegisterNUICallback('carMenuClose', function(_, cb)
    cb(1)
    close()
end)

RegisterNUICallback('carMenuCode', function(data, cb)
    cb(1)
    local index = type(data) == 'table' and math.tointeger(data.index)
    if not index or not Config.RadioCodes[index] then return end

    TriggerServerEvent('city_police:server:radioCode', index)
    exports.qbx_core:Notify(locale('car_menu_sent', Config.RadioCodes[index].code), 'success')
end)

RegisterNUICallback('carMenuRadar', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end

    if data.lock then
        TriggerEvent('city_police:client:radarLockToggle')
    else
        TriggerEvent('city_police:client:radarToggle')
    end
end)

AddEventHandler('city_police:client:radarState', function(on, locked)
    radar.on, radar.locked = on, locked
    if open then draw() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then close() end
end)
