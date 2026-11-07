-- The phone's server side: opening it from the item (or a burner, server/burner.lua), the player's settings (saved
-- in their character metadata), and notifications other resources send to a player.
local settings = require 'shared.settings'
local burner = require 'server.burner'

local META_KEY = 'phonesettings'
local THROTTLE_MS = 300
local lastSave = {}

exports.qbx_core:CreateUseableItem(Config.Item, function(source)
    local src = source

    if Player(src).state.isDead then return false end

    burner.stop(src)
    TriggerClientEvent('city_phone:client:toggle', src, false)

    -- The phone is not used up
    return false
end)

-- What the phone needs when it opens: the owner's name, number and settings (a burner shows only its number)
lib.callback.register('city_phone:profile', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local info = player.PlayerData.charinfo
    local burnerNumber = burner.of(source)

    return {
        name = burnerNumber and 'Burner' or ('%s %s'):format(info.firstname, info.lastname),
        number = burnerNumber or tostring(info.phone or ''),
        burner = burnerNumber ~= nil,
        settings = settings.clean(player.PlayerData.metadata[META_KEY]),
    }
end)

lib.callback.register('city_phone:saveSetting', function(source, key, value)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < THROTTLE_MS then return false end
    lastSave[src] = now

    if not settings.valid(key, value) then
        lib.print.warn(('city_phone: %s sent an invalid setting %s'):format(src, tostring(key)))
        return false
    end

    local current = settings.clean(player.PlayerData.metadata[META_KEY])
    current[key] = value
    player.Functions.SetMetaData(META_KEY, current)

    return true
end)

---Sends a phone notification to a player (shown as a banner and kept on the lock screen).
---@param src integer
---@param data { app?: string, title: string, text?: string, icon?: string }
local function notify(src, data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' or not GetPlayerName(src) then return false end

    TriggerClientEvent('city_phone:client:notify', src, {
        app = type(data.app) == 'string' and data.app or nil,
        title = data.title:sub(1, 60),
        text = type(data.text) == 'string' and data.text:sub(1, 300) or nil,
        icon = type(data.icon) == 'string' and data.icon or nil,
    })

    return true
end

exports('Notify', notify)

---Makes a player's phone ring (or stop) for everyone close by. Silent mode only vibrates; Do Not Disturb doesn't ring.
---@param src integer
---@param ringing boolean
exports('SetRinging', function(src, ringing)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local current = settings.clean(player.PlayerData.metadata[META_KEY])
    local value = false

    if ringing and not current.dnd then
        value = { tone = current.ringtone, loud = not current.silent }
    end

    Player(src).state:set('phoneRinging', value, true)
end)

---A player's phone settings (theme, ringtone, silent, dnd, ...)
exports('GetSettings', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and settings.clean(player.PlayerData.metadata[META_KEY]) or nil
end)

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)
