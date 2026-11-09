-- The Gang app page talks to this file (NUI callbacks); every request goes to a server callback that checks the
-- member's gang and grade again.
lib.locale()

-- Server callbacks the page may call (city_gangs:<name>)
local ACTIONS = {
    app = true, overview = true, members = true, member = true, setGrade = true, fire = true, leave = true,
    nearby = true, invite = true, log = true, drugs = true,
}

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action

    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local ok, result = lib.callback.await(('city_gangs:%s'):format(action), false, type(data.args) == 'table' and data.args or {})
    if not ok then return cb({ ok = false, reason = result or 'failed' }) end

    if action == 'app' then result.labels = lib.getLocales() end

    cb({ ok = true, data = result })
end)

-- A place from the drugs guide on the map; only a waypoint, so nothing to check on the server
RegisterNUICallback('gps', function(data, cb)
    local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
    if not x or not y then return cb(false) end

    SetNewWaypoint(x, y)
    exports.qbx_core:Notify(locale('waypoint_set'), 'success')
    cb(true)
end)

-- A gang member nearby asks this player to join
RegisterNetEvent('city_gangs:client:invite', function(gangLabel, inviterName)
    if GetInvokingResource() then return end

    local answer = lib.alertDialog({
        header = locale('invite_header'),
        content = locale('invite_text', inviterName, gangLabel),
        centered = true,
        cancel = true,
        labels = { confirm = locale('invite_accept'), cancel = locale('invite_decline') },
    }, Config.InviteSeconds * 1000)

    local ok, result = lib.callback.await('city_gangs:answer', false, answer == 'confirm')

    if not ok then return exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error') end
    if answer == 'confirm' then exports.qbx_core:Notify(locale('notify_joined', result), 'success') end
end)
