RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    lib.notify({
        title = Config.CityName,
        description = ('Welcome to %s!'):format(Config.CityName),
        type = 'inform',
    })
end)

RegisterNetEvent('city_base:client:copyCoords', function()
    if GetInvokingResource() then return end

    local coords = GetEntityCoords(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, GetEntityHeading(cache.ped))

    lib.setClipboard(text)
    lib.print.info(text)
    lib.notify({ title = 'Copied', description = text, type = 'inform', duration = 8000 })
end)
