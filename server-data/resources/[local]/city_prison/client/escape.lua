-- Gate terminals (anyone with a jammer or a trojan USB, from inside or outside) and the prison alarm.

local ALARM = 'PRISON_ALARMS'
local HEAR_DISTANCE = 450.0

local zones = {}
local hacking = false

local function hack(index)
    if hacking then return end
    hacking = true

    local ok, seconds = lib.callback.await('city_prison:beginHack', false, index)
    if not ok then
        hacking = false
        if seconds then lib.notify({ description = locale('error_' .. seconds), type = 'error' }) end
        return
    end

    lib.requestAnimDict('anim@heists@prison_heiststation@cop_reactions')
    TaskPlayAnim(cache.ped, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict('anim@heists@prison_heiststation@cop_reactions')

    local done = lib.progressBar({
        duration = seconds * 1000,
        label = locale('hacking'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    local success = done and lib.skillCheck(Config.HackSkillCheck)
    ClearPedTasks(cache.ped)

    if not done then
        hacking = false
        return
    end

    local finished, opened = lib.callback.await('city_prison:finishHack', false, index, success)
    hacking = false

    if not finished then
        if opened then lib.notify({ description = locale('error_' .. opened), type = 'error' }) end
        return
    end

    lib.notify({ description = opened and locale('hack_done') or locale('hack_failed'), type = opened and 'success' or 'error' })
end

CreateThread(function()
    for index, terminal in ipairs(Config.Terminals) do
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = terminal.coords,
            radius = 0.5,
            options = { {
                name = 'city_prison:hack',
                icon = 'fas fa-laptop-code',
                label = locale('target_hack'),
                onSelect = function() hack(index) end,
            } },
        })
    end
end)

local function alarm(on)
    if not on then return StopAlarm(ALARM, true) end
    if #(GetEntityCoords(cache.ped) - Config.Prison.center) > HEAR_DISTANCE then return end

    local deadline = GetGameTimer() + 5000
    while not PrepareAlarm(ALARM) and GetGameTimer() < deadline do Wait(100) end

    StartAlarm(ALARM, true)
end

AddStateBagChangeHandler('prisonAlarm', 'global', function(_, _, value)
    alarm(value == true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    StopAlarm(ALARM, true)
end)
