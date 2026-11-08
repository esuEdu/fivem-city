lib.print.info(('%s base resource started'):format(Config.CityName))

-- Dev helper: copies the admin's position as a vec4, to place things in config files
lib.addCommand('coords', {
    help = 'Copy your position (vec4) to the clipboard',
    restricted = 'group.admin',
}, function(source)
    -- source 0 = server console, which has no position
    if source == 0 then return end

    TriggerClientEvent('city_base:client:copyCoords', source)
end)
