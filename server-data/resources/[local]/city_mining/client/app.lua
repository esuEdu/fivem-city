-- The Mining app page (inside the tablet) talks to this file; every request goes to a server callback that works out
-- the character from source and checks everything again.
local levels = require 'shared.levels'

-- Server callbacks the page may call (city_mining:app:<name>)
local ACTIONS = { profile = true, learn = true, market = true, orders = true }

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action
    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local ok, result = lib.callback.await(('city_mining:app:%s'):format(action), false, data.args)
    if not ok then return cb({ ok = false, reason = result or 'failed' }) end

    cb({ ok = true, data = result })
end)

-- What the page needs once: its texts and the skill tree layout
RegisterNUICallback('setup', function(_, cb)
    cb({ labels = lib.getLocales(), branches = levels.branches, features = Config.Features })
end)

RegisterNUICallback('track', function(_, cb)
    cb(1)
    TriggerEvent('city_mining:client:track')
end)
