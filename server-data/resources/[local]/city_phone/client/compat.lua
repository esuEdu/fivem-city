-- Client events scripts still send to the old QBCore phone (qb-phone): they become phone notifications.
local notify = exports[cache.resource]

-- qbx_police / qbx_truckrobbery alerts (tracker, robbery)
RegisterNetEvent('qb-phone:client:addPoliceAlert', function(alert)
    if type(alert) ~= 'table' then return end

    notify:Notify({
        app = 'police',
        title = type(alert.title) == 'string' and alert.title or 'Police',
        text = type(alert.description) == 'string' and alert.description or nil,
    })
end)

-- qbx_lapraces
RegisterNetEvent('qb-phone:client:RaceNotify', function(message)
    if type(message) ~= 'string' then return end

    notify:Notify({ app = 'races', title = 'Races', text = message })
end)

-- Sent by qbx_core and qbx_lapraces for the old phone's own screens; nothing to show
RegisterNetEvent('qb-phone:client:RemoveBankMoney', function() end)
RegisterNetEvent('qb-phone:client:UpdateLapraces', function() end)
