local config = require 'config.client'
local plyState = LocalPlayer.state

---Initialize health and armor settings on the player's ped
---@param ped number
---@param playerId number
---@param playerMetadata any
local function initHealthAndArmor(ped, playerId, playerMetadata)
    SetEntityMaxHealth(ped, 200)

    -- 100 or less is dead in GTA. Without isdead/inlaststand the character didn't die: it's a bad save (older ones
    -- stored 0 when the ped was already gone), so they get up healthy instead of joining dead
    local health = playerMetadata.health or 200
    if health <= 100 and not playerMetadata.isdead and not playerMetadata.inlaststand then health = 200 end

    SetEntityHealth(ped, health)
    SetPlayerHealthRechargeMultiplier(playerId, 0.0)
    SetPlayerHealthRechargeLimit(playerId, 0.0)
    SetPedArmour(ped, playerMetadata.armor)
end

---starts death or last stand based off of player's metadata
---@param metadata any
local function initDeathAndLastStand(metadata)
    if not plyState.isLoggedIn then return end
    if metadata.isdead then
        DeathTime = config.deathTime
        OnDeath()
    elseif metadata.inlaststand then
        StartLastStand()
    end
end

---initialize settings from player object
local function onPlayerLoaded()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    CreateThread(function()
        Wait(1000)
        initHealthAndArmor(cache.ped, cache.playerId, QBX.PlayerData.metadata)
        initDeathAndLastStand(QBX.PlayerData.metadata)
    end)
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', onPlayerLoaded)

AddEventHandler('onResourceStart', function(resourceName)
    if cache.resource ~= resourceName then return end
    onPlayerLoaded()
end)
