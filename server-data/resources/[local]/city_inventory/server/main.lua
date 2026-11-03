local players = require 'server.players'
local stashes = require 'server.stashes'
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

AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    stashes.close(src)
    players.unload(src)
end)

AddEventHandler('playerDropped', function()
    stashes.close(source)
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
    players.saveAll(false)
    stashes.saveAll(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    players.saveAll(false)
    stashes.saveAll(false)
end)
