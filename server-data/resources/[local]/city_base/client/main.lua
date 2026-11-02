RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    lib.notify({
        title = Config.CityName,
        description = ('Welcome to %s!'):format(Config.CityName),
        type = 'inform',
    })
end)
