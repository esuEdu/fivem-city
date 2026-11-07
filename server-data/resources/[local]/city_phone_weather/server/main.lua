-- The weather now and the coming changes, from Renewed-Weathersync (GlobalState.weather and its GetForecast export,
-- added by scripts/patches/Renewed-Weathersync.patch)
local last = {}

lib.callback.register('city_phone_weather:get', function(source)
    local now = GetGameTimer()
    if last[source] and now - last[source] < 1000 then return end
    last[source] = now

    local forecast = {}

    if GetResourceState('Renewed-Weathersync') == 'started' then
        local ok, list = pcall(function() return exports['Renewed-Weathersync']:GetForecast(6) end)
        if ok and type(list) == 'table' then forecast = list end
    end

    return { current = GlobalState.weather, forecast = forecast }
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
