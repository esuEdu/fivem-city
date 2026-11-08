-- Starts the police: tables, the MDT app on the tablet, the duty roster and the calls.
lib.locale()

local db = require 'server.db'

require 'server.roster'
require 'server.dispatch'

MySQL.ready(db.init)

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/index.html',
        icon = Config.App.icon,
        access = { jobs = { [Config.Job] = 0 } },
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)
