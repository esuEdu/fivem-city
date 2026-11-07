-- The city services (190, 192, mechanic): fixed contacts on every phone. Calling one sends a written call to
-- city_dispatch with the caller's location instead of ringing anyone.
local common = require 'server.common'

local function dispatch()
    return GetResourceState('city_dispatch') == 'started'
end

lib.callback.register('city_phone_calls:services', function()
    return dispatch() and exports.city_dispatch:Services() or {}
end)

lib.callback.register('city_phone_calls:report', function(source, service, kind, text, anonymous)
    local src = source
    local _, citizenid = common.player(src)
    if not citizenid or common.throttled(src, 'report', 2000) then return false, 'invalid' end
    if not common.hasPhone(src) or not dispatch() then return false, 'invalid' end
    if type(service) ~= 'string' or type(kind) ~= 'string' or (text ~= nil and type(text) ~= 'string') then return false, 'invalid' end

    return exports.city_dispatch:Report(src, service, kind, text or '', anonymous == true)
end)
