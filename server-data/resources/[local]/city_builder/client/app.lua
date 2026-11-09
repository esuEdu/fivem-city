-- The Builder app page (inside the tablet): shows the counts and opens the editor.
local world = require 'client.world'

RegisterNUICallback('appInfo', function(_, cb)
    local props, groups, hides = 0, 0, 0

    for _ in pairs(world.props) do props = props + 1 end
    for _ in pairs(world.groups) do groups = groups + 1 end
    for _ in pairs(world.hides) do hides = hides + 1 end

    cb({ labels = lib.getLocales(), props = props, groups = groups, hides = hides, max = Config.MaxProps })
end)

RegisterNUICallback('appStart', function(_, cb)
    cb(true)

    exports.city_os:Close()
    Wait(500)
    TriggerEvent('city_builder:client:start')
end)
