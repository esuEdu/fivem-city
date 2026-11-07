-- The "How did staff do?" prompt a player gets when staff close their report (web/prompt.html, this resource's
-- ui_page). The server only takes a rating it asked for.

local theme = require '@city_ui.theme'

---@type integer? the report being rated
local asking = nil

local function hide()
    asking = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideRating' })
end

RegisterNetEvent('city_staff:client:askRating', function(report)
    if GetInvokingResource() or type(report) ~= 'table' or type(report.id) ~= 'number' then return end

    asking = report.id
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'askRating', report = report, theme = theme, labels = lib.getLocales() })
end)

RegisterNUICallback('rate', function(data, cb)
    if not asking or type(data) ~= 'table' then return cb({ ok = false }) end

    local ok = lib.callback.await('city_staff:rateReport', false, { id = asking, stars = data.stars, tags = data.tags, comment = data.comment })
    cb({ ok = ok == true })
end)

RegisterNUICallback('closeRating', function(_, cb)
    cb(1)
    hide()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and asking then SetNuiFocus(false, false) end
end)
