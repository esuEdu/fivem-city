-- The phone's server side: opening it from the item, the player's settings (saved in their character metadata),
-- and notifications other resources send to a player.
local settings = require 'shared.settings'

local META_KEY = 'phonesettings'
local THROTTLE_MS = 300
local lastSave = {}

exports.qbx_core:CreateUseableItem(Config.Item, function(source)
    local src = source

    if Player(src).state.isDead then return false end

    TriggerClientEvent('city_phone:client:toggle', src)

    -- The phone is not used up
    return false
end)

-- What the phone needs when it opens: the owner's name, number and settings
lib.callback.register('city_phone:profile', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local info = player.PlayerData.charinfo

    return {
        name = ('%s %s'):format(info.firstname, info.lastname),
        number = tostring(info.phone or ''),
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

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)
