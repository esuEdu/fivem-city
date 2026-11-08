local appearance = require 'shared.appearance'

local SAVE_COOLDOWN_MS = 3000
local lastSave = {}

local options = { blocked = Config.Blocked, eyeColors = Config.EyeColors }

local function refuse(src, reason)
    lib.print.warn(('city_character: refused look from %s (%s)'):format(src, reason))
    return false
end

-- The creator saves a character's first look only: later changes go through the clothing shop, barber and surgeon
lib.callback.register('city_character:saveLook', function(source, draft)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < SAVE_COOLDOWN_MS then return false end
    lastSave[src] = now

    local citizenid = player.PlayerData.citizenid
    local hasLook = MySQL.scalar.await('SELECT 1 FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
    if hasLook then return refuse(src, 'already has a look') end

    local look, reason = appearance.build(draft, options)
    if not look then return refuse(src, reason) end

    local gender = player.PlayerData.charinfo.gender
    if (gender == 1) ~= (draft.sex == 'f') then return refuse(src, 'sex does not match the character') end

    MySQL.insert.await('INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)', {
        citizenid, look.model, json.encode(look),
    })

    return true
end)

-- Whether each of the player's characters already has a look, so the select screen can send look-less ones to the creator
lib.callback.register('city_character:looks', function(source)
    local src = source
    local license2 = GetPlayerIdentifierByType(src, 'license2')
    local license = GetPlayerIdentifierByType(src, 'license')

    local rows = MySQL.query.await([[
        SELECT p.citizenid FROM players p
        JOIN playerskins s ON s.citizenid = p.citizenid AND s.active = 1
        WHERE p.license = ? OR p.license = ?
    ]], { license2 or '', license or '' })

    local looks = {}
    for i = 1, #rows do looks[rows[i].citizenid] = true end

    return looks
end)

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)
