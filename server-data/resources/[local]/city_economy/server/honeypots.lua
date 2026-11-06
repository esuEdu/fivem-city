-- Event names cheat menus try first. Nothing on this server sends them, so a call means a modified client.
local flags = require 'server.flags'
local settings = require 'server.config'

for i = 1, #settings.honeypots do
    local name = settings.honeypots[i]

    RegisterNetEvent(name, function(...)
        local src = source
        local args = { ... }

        -- Keep the context small: a cheater could send huge tables
        for j = #args, 4, -1 do args[j] = nil end
        for j = 1, #args do
            args[j] = type(args[j]) == 'table' and 'table' or tostring(args[j]):sub(1, 64)
        end

        flags.add(src, nil, 'honeypot', 5, { event = name, args = args })
    end)
end
