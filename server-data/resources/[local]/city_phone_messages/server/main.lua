-- Creates the tables and loads the server parts (chats, groups, live location)
local store = require 'server.store'

require 'server.chats'
require 'server.groups'
require 'server.live'

CreateThread(store.init)

-- Names for the numbers in a player's chats, from their Phone contacts
lib.callback.register('city_phone_messages:contacts', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or GetResourceState('city_phone_calls') ~= 'started' then return {} end

    return exports.city_phone_calls:Contacts(player.PlayerData.citizenid)
end)
