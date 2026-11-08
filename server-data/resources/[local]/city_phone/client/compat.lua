-- Client events scripts still send to the old QBCore phone (qb-phone): they become phone notifications.
local notify = exports[cache.resource]

-- Robbery alerts
RegisterNetEvent('qb-phone:client:addPoliceAlert', function(alert)
    if type(alert) ~= 'table' then return end

    notify:Notify({
        app = 'police',
        title = type(alert.title) == 'string' and alert.title or 'Police',
        text = type(alert.description) == 'string' and alert.description or nil,
    })
end)

-- Sent by qbx_core for the old phone's own screen; nothing to show
RegisterNetEvent('qb-phone:client:RemoveBankMoney', function() end)
