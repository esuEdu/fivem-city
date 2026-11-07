-- Speed cameras: driving past one tells the server, which reads the speed and the plate itself.

if not Config.Radars.enabled then return end

local points = {}

for index, radar in ipairs(Config.Radars.locations) do
    points[index] = lib.points.new({
        coords = radar.coords,
        distance = 25.0,
        onEnter = function()
            if cache.vehicle and cache.seat == -1 then
                TriggerServerEvent('city_police:server:radar', index)
            end
        end,
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, point in ipairs(points) do point:remove() end
end)
