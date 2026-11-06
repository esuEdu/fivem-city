local accounts = require 'server.accounts'
local ledger = require 'server.ledger'
local mirror = require 'server.mirror'

---After every posting: refresh the qbx copy of whoever was touched, and tell city_bank about money coming into a
---personal account (it takes the debt retention from there). Postings from qbx_core already updated its copy.
ledger.onPosted = function(touched, entries, info)
    local owners = {}

    for i = 1, #entries do
        local account = touched[entries[i].account]

        if account.owner and (account.type == 'personal' or account.type == 'cash') then
            if not info.skipMirror then owners[account.owner] = true end

            if account.type == 'personal' and entries[i].delta > 0 then
                TriggerEvent('city_economy:server:credited', account.id, account.owner, entries[i].delta, info.reason)
            end
        end
    end

    for citizenid in pairs(owners) do
        local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)

        if player then mirror.sync(player.PlayerData.source, citizenid) end
    end
end

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
