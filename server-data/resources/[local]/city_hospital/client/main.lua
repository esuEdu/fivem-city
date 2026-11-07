-- The downed screen: who is on duty, whether someone is coming, the hospital timer and the keys (respawn, SOS, prayer).
-- Everything shown comes from the server (city_hospital:status); the keys only ask.
lib.locale()

local theme = require '@city_ui.theme'
local npc = require 'client.npc'

local POLL_MS = 2000
local LABEL_KEYS = {
    'ui_unconscious', 'ui_finalized', 'ui_finalized_hint', 'ui_ems_on_duty', 'ui_ems_coming', 'ui_no_ems_coming',
    'ui_wait', 'ui_respawn', 'ui_sos', 'ui_sos_sent', 'ui_pray', 'ui_npc_coming',
}

local downed = false
local status = {}

local function labels()
    local list = {}

    for _, key in ipairs(LABEL_KEYS) do list[key] = locale(key) end

    return list
end

local function show(data)
    SendNUIMessage({ action = 'downed', data = data })
end

local function refresh()
    local data = lib.callback.await('city_hospital:status', false)
    if not data then return end

    status = data
    data.npcComing = npc.active()
    show(data)
end

local NOTIFY_REASONS = {
    finalized = 'notify_finalized',
    ems_on_duty = 'notify_ems_on_duty',
    already_prayed = 'notify_already_prayed',
    already_called = 'notify_already_called',
    cooldown = 'notify_cooldown',
}

local function notifyReason(reason)
    local key = NOTIFY_REASONS[reason]
    if key then exports.qbx_core:Notify(locale(key), 'error') end
end

local function sendSos()
    local ok, reason = lib.callback.await('city_hospital:sos', false)

    if ok then exports.qbx_core:Notify(locale('notify_sos_sent'), 'success') else notifyReason(reason) end

    refresh()
end

local function pray()
    if npc.active() then return end

    local ok, token = lib.callback.await('city_hospital:pray', false)
    if not ok then return notifyReason(token) end

    npc.start(token)
    refresh()
end

local function respawn()
    if not lib.callback.await('city_hospital:respawn', false) then
        exports.qbx_core:Notify(locale('notify_respawn_failed'), 'error')
    end
end

-- Runs only while down. qbx_medical disables every control then, so the keys are read as disabled controls.
local function downedLoop()
    local nextPoll, holdStart = 0, nil

    while downed do
        local now = GetGameTimer()

        if now >= nextPoll then
            nextPoll = now + POLL_MS
            CreateThread(refresh)
        end

        if IsDisabledControlPressed(0, Config.Keys.respawn) and status.remaining == 0 then
            holdStart = holdStart or now

            if now - holdStart >= Config.RespawnHoldMs then
                holdStart = nil
                respawn()
            end
        else
            holdStart = nil
        end

        if IsDisabledControlJustPressed(0, Config.Keys.sos) and not status.finalized and not status.sos then
            CreateThread(sendSos)
        end

        if IsDisabledControlJustPressed(0, Config.Keys.pray) and status.canPray then
            CreateThread(pray)
        end

        Wait(0)
    end
end

local function setDowned(value)
    if value == downed then return end

    downed = value

    if downed then
        -- qbx_medical would respawn the player itself when its own timer ends; the hospital decides instead
        exports.qbx_medical:DisableRespawn()
        status = {}
        CreateThread(downedLoop)
    else
        npc.stop()
        show(false)
    end
end

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    setDowned(value == true)
end)

RegisterNetEvent('city_hospital:client:prayerCancelled', function()
    npc.stop()
    exports.qbx_core:Notify(locale('notify_prayer_cancelled'), 'error')
end)

-- The page asks once it has loaded, so the setup is never sent before it can listen
RegisterNUICallback('ready', function(_, cb)
    cb({ theme = theme, labels = labels() })
end)

CreateThread(function()
    exports.qbx_medical:DisableRespawn()
    setDowned(LocalPlayer.state.isDead == true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.qbx_medical:AllowRespawn()
end)
