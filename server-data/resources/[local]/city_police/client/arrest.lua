-- The arrested player's screen: months, crimes, the officer. For now this is the whole sentence; serving it comes with
-- our prison script.

local theme = require '@city_ui.theme'

local showing = false

RegisterNetEvent('city_police:client:arrested', function(data)
    if GetInvokingResource() or type(data) ~= 'table' then return end

    showing = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'arrested', theme = theme, charges = data.charges, labels = {
        title = locale('arrest_title'),
        months = locale('arrest_months', data.months),
        fine = data.fine > 0 and locale('arrest_fine', data.fine) or nil,
        officer = locale('arrest_officer', data.officer),
        charges = locale('arrest_charges'),
        ok = locale('arrest_ok'),
    } })
end)

RegisterNUICallback('arrestClose', function(_, cb)
    cb(1)
    if not showing then return end

    showing = false
    SetNuiFocus(false, false)
end)
