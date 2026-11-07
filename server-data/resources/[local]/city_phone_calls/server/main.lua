-- Loads the server modules in order and creates the tables
local store = require 'server.store'

require 'server.calls'

CreateThread(store.init)

-- For other phone apps (Messages): a player's saved name for a number, and their contact list
exports('ContactName', function(citizenid, number)
    if type(citizenid) ~= 'string' or type(number) ~= 'string' then return end

    for _, contact in ipairs(store.contacts(citizenid)) do
        if contact.number == number then return contact.name end
    end
end)

exports('Contacts', function(citizenid)
    return type(citizenid) == 'string' and store.contacts(citizenid) or {}
end)
