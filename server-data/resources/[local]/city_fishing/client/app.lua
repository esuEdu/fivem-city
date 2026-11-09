-- The Fishing app page (inside the tablet) talks to this file; every request goes to a server callback that works out
-- the character from source and checks everything again.
local levels = require 'shared.levels'

-- Server callbacks the page may call (city_fishing:app:<name>)
local ACTIONS = {
    profile = true, learn = true, collection = true, market = true, events = true, pots = true,
    join = true, startTournament = true, startFrenzy = true,
}

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action
    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local ok, result = lib.callback.await(('city_fishing:app:%s'):format(action), false, data.args)
    if not ok then return cb({ ok = false, reason = result or 'failed' }) end

    cb({ ok = true, data = result })
end)

-- What the page needs once: its texts and the skill tree layout
RegisterNUICallback('setup', function(_, cb)
    cb({ labels = lib.getLocales(), branches = levels.branches, features = Config.Features })
end)

-- A route to one of the player's crab pots
RegisterNUICallback('route', function(data, cb)
    cb(1)

    local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
    if not x or not y then return end

    SetNewWaypoint(x, y)
    lib.notify({ description = locale('route_set'), type = 'inform' })
end)
