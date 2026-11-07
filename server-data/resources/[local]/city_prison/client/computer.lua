-- The prison computer (police on duty): opens the panel on the page and passes its actions to the server.

local LABELS = {
    'computer_title', 'tab_inmates', 'tab_history', 'col_name', 'col_status', 'col_left', 'col_sentence', 'col_reduced',
    'col_officer', 'col_action', 'col_when', 'col_months', 'status_serving', 'status_escaped', 'online', 'offline',
    'set_time', 'release', 'clear_escape', 'save', 'cancel', 'close', 'empty_inmates', 'empty_history', 'owed',
    'months_short', 'action_jailed', 'action_released', 'action_escaped', 'action_set_time', 'action_cleared',
}

local zone
local open = false

local function labels()
    local result = {}
    for _, key in ipairs(LABELS) do result[key] = locale(key) end
    return result
end

local function show()
    if open then return end

    local ok, data = lib.callback.await('city_prison:computer', false, 'list')
    if not ok then return lib.notify({ description = locale('error_' .. (data or 'no_access')), type = 'error' }) end

    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'computer', data = data, labels = labels() })
end

RegisterNUICallback('computerClose', function(_, cb)
    cb(1)
    open = false
    SetNuiFocus(false, false)
end)

RegisterNUICallback('computerAction', function(body, cb)
    if not open or type(body) ~= 'table' then return cb({ ok = false }) end

    local ok, data = lib.callback.await('city_prison:computer', false, body.action, body.data)
    if not ok then lib.notify({ description = locale('error_' .. (data or 'invalid')), type = 'error' }) end

    cb({ ok = ok, data = ok and data or nil })
end)

CreateThread(function()
    zone = exports.ox_target:addSphereZone({
        coords = Config.Computer.coords,
        radius = Config.Computer.radius,
        options = { {
            name = 'city_prison:computer',
            icon = 'fas fa-desktop',
            label = locale('target_computer'),
            groups = { [Config.PoliceJob] = Config.ComputerGrades.view },
            onSelect = show,
        } },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if zone then exports.ox_target:removeZone(zone) end
    if open then SetNuiFocus(false, false) end
end)
