-- What other resources use: register apps, send notifications and badges, unlock hidden apps. See docs/city-os.md.

local settings = require 'shared.settings'
local apps = require 'server.apps'
local sessions = require 'server.sessions'
local notifications = require 'server.notifications'

---@param target unknown a server id, or a citizenid
---@return string? citizenid
---@return integer? src when online
local function resolve(target)
    local src = math.tointeger(tonumber(target))

    if src then
        local player = exports.qbx_core:GetPlayer(src)
        return player and player.PlayerData.citizenid, player and src
    end

    if type(target) ~= 'string' then return end

    local player = exports.qbx_core:GetPlayerByCitizenId(target)

    return target, player and player.PlayerData.source
end

exports('RegisterApp', function(data)
    local resource = GetInvokingResource() or cache.resource
    local success, reason = apps.register(resource, data)

    if not success then
        lib.print.warn(('%s could not register an app: %s'):format(resource, reason))
        return false, reason
    end

    sessions.refreshAll()

    return true
end)

exports('Notify', function(target, data)
    local citizenid, src = resolve(target)
    if not citizenid then return false, 'no_player' end

    local note, reason = notifications.validate(data)
    if not note then
        lib.print.warn(('%s sent an invalid notification: %s'):format(GetInvokingResource(), reason))
        return false, reason
    end

    -- Only for an app the player can see, so a hidden app never gives itself away
    local app = note.app and apps.get(note.app)
    if note.app and not app then return false, 'unknown_app' end

    if app and src then
        local viewer = sessions.viewer(src)
        if not viewer or not apps.canSee(app, viewer) then return false, 'no_access' end
    end

    notifications.add(citizenid, note)

    if src and sessions.get(src) then
        TriggerClientEvent('city_os:client:notify', src, sessions.toClient(note))
    end

    return true
end)

exports('SetBadge', function(target, appId, count)
    local citizenid, src = resolve(target)
    count = math.tointeger(tonumber(count))
    if not citizenid or not settings.isAppId(appId) or not count then return false end

    notifications.setBadge(citizenid, appId, math.max(count, 0))

    if src then sessions.refresh(src) end

    return true
end)

---Shows (or hides again) apps registered with access.unlock = key.
---@param target string | integer citizenid or server id
---@param key string
---@param unlocked? boolean default true
exports('Unlock', function(target, key, unlocked)
    local citizenid, src = resolve(target)
    if not citizenid or not settings.isAppId(key) then return false end

    sessions.setUnlock(citizenid, key, unlocked ~= false)

    if src then sessions.refresh(src) end

    return true
end)

exports('IsUnlocked', function(target, key)
    local citizenid = resolve(target)

    return citizenid ~= nil and sessions.unlocks(citizenid)[key] == true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then return end

    if apps.removeResource(resource) then sessions.refreshAll() end
end)
