-- The faction tablet app (web/app/) talks to this file. Every request goes to a server callback that resolves the
-- viewer's faction from their gang and checks it again (city_orgs:app:<name>).

-- Server callbacks the page may call (city_orgs:app:<name>)
local ACTIONS = {
    app = true, dashboard = true, activity = true,
    vault = true, deposit = true, withdraw = true,
    goals = true, setGoal = true, clearGoal = true,
    team = true, offer = true, setGrade = true, fire = true,
}

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action
    local args = type(data) == 'table' and type(data.args) == 'table' and data.args or {}

    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local ok, result = lib.callback.await(('city_orgs:app:%s'):format(action), false, args)
    if not ok then return cb({ ok = false, reason = result or 'failed' }) end

    if action == 'app' then result.labels = lib.getLocales() end

    cb({ ok = true, data = result })
end)

RegisterNetEvent('city_orgs:client:appMessage', function(message)
    if GetInvokingResource() or type(message) ~= 'table' then return end

    local playerData = exports.qbx_core:GetPlayerData()
    local gang = playerData and playerData.gang
    if not gang or gang.name == 'none' then return end

    exports.city_os:SendAppMessage(('org_%s'):format(gang.name), message)
end)

-- A leader offered this player the faction (Management tab); no answer in time is a no
lib.callback.register('city_orgs:orgOffer', function(faction, grade, boss)
    local answered = false

    SetTimeout(Config.OfferSeconds * 1000, function()
        if not answered then lib.closeAlertDialog() end
    end)

    local answer = lib.alertDialog({
        header = locale('offer_title'),
        content = locale('offer_text', boss, faction, grade),
        centered = true,
        cancel = true,
        labels = { confirm = locale('offer_accept'), cancel = locale('offer_decline') },
    })

    answered = true

    return answer == 'confirm'
end)
