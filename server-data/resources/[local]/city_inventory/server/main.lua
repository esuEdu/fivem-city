local players = require 'server.players'
local stashes = require 'server.stashes'
local trades = require 'server.trades'
local other = require 'server.other'
local storage = require 'server.storage'

---@param src integer
local function loadPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    players.load(src, player.PlayerData.citizenid)
end

MySQL.ready(function()
    storage.init()

    -- Restarting the resource with players online: load everyone already logged in
    for _, playerData in ipairs(exports.qbx_core:GetPlayersData()) do
        loadPlayer(playerData.source)
    end
end)

-- qbx_core sets this when a character has loaded, for whichever inventory resource is running
AddStateBagChangeHandler('loadInventory', nil, function(bagName, _, value)
    if not value then return end

    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    CreateThread(function()
        loadPlayer(src)
    end)
end)

-- Close whatever is open next to the inventory first: a trade gives offered items back before the inventory is saved
AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    other.closeAll(src)
    players.unload(src)
end)

AddEventHandler('playerDropped', function()
    other.closeAll(source)
    players.unload(source)
end)

CreateThread(function()
    while true do
        Wait(Config.AutosaveMinutes * 60000)
        players.saveAll()
        stashes.saveAll()
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    trades.cancelAll()
    players.saveAll(false)
    stashes.saveAll(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    trades.cancelAll()
    players.saveAll(false)
    stashes.saveAll(false)
end)
