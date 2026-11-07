-- Adds Clock to city_phone. Alarms and the timer live here (not in the page) so they ring with the phone closed:
-- the phone's alarm sound plays only for this player, even in silent mode, until stopped or for a minute.
local APP = 'clock'
local RING_SECONDS = 60

local alarms = {}
local fired = {} -- alarm id -> 'YYYY-MM-DD HH:MM' it last rang, so it rings once per minute
local timer = nil -- { ends = game timer ms, total = seconds }
local ringingUntil = 0

local TEXTS = {
    en = { alarm = 'Alarm', timer = 'Timer', done = "Time's up", stop = 'Stop' },
    ['pt-br'] = { alarm = 'Alarme', timer = 'Timer', done = 'O tempo acabou', stop = 'Parar' },
}

local function t(key)
    local settings = exports.city_phone:GetSettings() or {}
    return (TEXTS[settings.language] or TEXTS.en)[key]
end

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Clock',
        labels = { ['pt-br'] = 'Relógio' },
        icon = 'web/icon.svg',
        color = '#000000',
        page = 'web/index.html',
        order = 21,
    })
end

local function loadAlarms()
    alarms = lib.callback.await('city_phone_clock:alarms', false) or {}
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
    if LocalPlayer.state.isLoggedIn then loadAlarms() end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2000, loadAlarms)
end)

local function stopRinging()
    ringingUntil = 0
    exports.city_phone:SetAlarmSound(false)
end

local function ring(title, text)
    ringingUntil = GetGameTimer() + RING_SECONDS * 1000
    exports.city_phone:SetAlarmSound(true)
    exports.city_phone:Notify({
        app = 'clock', icon = 'bell', title = title, text = text, force = true, sound = false,
        action = { event = 'city_phone_clock:client:stop' },
    })
end

AddEventHandler('city_phone_clock:client:stop', stopRinging)

-- Alarms: checked against the computer's real clock every few seconds
CreateThread(function()
    while true do
        Wait(5000)

        if ringingUntil > 0 and GetGameTimer() > ringingUntil then stopRinging() end

        local year, month, day, hour, minute = GetLocalTime()
        local stamp = ('%04d-%02d-%02d %02d:%02d'):format(year, month, day, hour, minute)

        for _, alarm in ipairs(alarms) do
            if alarm.enabled and alarm.hour == hour and alarm.minute == minute and fired[alarm.id] ~= stamp then
                fired[alarm.id] = stamp
                ring(t('alarm'), alarm.label ~= '' and alarm.label or ('%02d:%02d'):format(hour, minute))

                -- A one-time alarm turns itself off
                if not alarm.repeats then
                    alarm.enabled = false
                    CreateThread(function()
                        local list = lib.callback.await('city_phone_clock:saveAlarm', false, alarm)
                        if list then alarms = list end
                    end)
                end
            end
        end
    end
end)

local function timerLeft()
    return timer and math.max(0, math.ceil((timer.ends - GetGameTimer()) / 1000)) or 0
end

-- The timer counts down in the dynamic island while it runs
local function runTimer()
    CreateThread(function()
        while timer do
            local left = timerLeft()

            if left <= 0 then
                timer = nil
                exports.city_phone:SetActivity('timer', nil)
                exports.city_phone:SendAppMessage(APP, { action = 'timer', left = 0 })
                ring(t('timer'), t('done'))
                return
            end

            exports.city_phone:SetActivity('timer', { icon = 'bell', color = '#ff9f0a', text = t('timer'), detail = ('%d:%02d'):format(math.floor(left / 60), left % 60) })
            Wait(1000)
        end

        exports.city_phone:SetActivity('timer', nil)
    end)
end

RegisterNUICallback('state', function(_, cb)
    cb({ ok = true, result = { alarms = alarms, timer = timer and { left = timerLeft(), total = timer.total } or nil } })
end)

RegisterNUICallback('saveAlarm', function(data, cb)
    local list, reason = lib.callback.await('city_phone_clock:saveAlarm', false, data.alarm)
    if list then alarms = list end
    cb({ ok = list ~= false and list ~= nil, result = alarms, reason = reason })
end)

RegisterNUICallback('deleteAlarm', function(data, cb)
    local list = lib.callback.await('city_phone_clock:deleteAlarm', false, data.id)
    if list then alarms = list end
    cb({ ok = list ~= false and list ~= nil, result = alarms })
end)

RegisterNUICallback('startTimer', function(data, cb)
    local seconds = math.tointeger(tonumber(data.seconds))
    if not seconds or seconds < 1 or seconds > 24 * 3600 then return cb({ ok = false }) end

    local wasRunning = timer ~= nil
    timer = { ends = GetGameTimer() + seconds * 1000, total = seconds }
    if not wasRunning then runTimer() end

    cb({ ok = true })
end)

RegisterNUICallback('stopTimer', function(_, cb)
    timer = nil
    stopRinging()
    cb({ ok = true })
end)

RegisterNUICallback('stopRinging', function(_, cb)
    stopRinging()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if ringingUntil > 0 then exports.city_phone:SetAlarmSound(false) end
    exports.city_phone:SetActivity('timer', nil)
end)
