local accounts = require 'server.accounts'
local mirror = require 'server.mirror'

CreateThread(function()
    accounts.init()

    -- Players already online when the resource (re)starts get their balances pushed again
    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        mirror.sync(src, player.PlayerData.citizenid)
    end

    lib.print.info('Economy ready')
end)

-- First load of a character creates its accounts (and pays the starting money); every load re-syncs the qbx copy
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local citizenid = player.PlayerData.citizenid

    accounts.wait()
    mirror.sync(src, citizenid)
end)
