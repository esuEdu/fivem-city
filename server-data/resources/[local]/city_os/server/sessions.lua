-- Who has a tablet open, which one, and whether they got past its passcode. Everything a player does in the
-- tablet goes through their session, so a client can't act on a tablet it didn't open.

local apps = require 'server.apps'
local tablets = require 'server.tablets'
local notifications = require 'server.notifications'

local sessions = {}

---@class Session
---@field tablet Tablet
---@field citizenid string
---@field unlocked boolean

---@type table<integer, Session>
local open = {}

---@type table<string, table<string, true>> unlocks per citizenid, loaded when they open a tablet
local unlockCache = {}

---@param src integer
---@return Session?
function sessions.get(src)
    return open[src]
end

---@param src integer
---@param session Session
function sessions.start(src, session)
    open[src] = session
end

---@param src integer
function sessions.stop(src)
    open[src] = nil
end

---@param citizenid string
---@return table<string, true>
function sessions.unlocks(citizenid)
    if not unlockCache[citizenid] then unlockCache[citizenid] = tablets.loadUnlocks(citizenid) end

    return unlockCache[citizenid]
end

---@param citizenid string
---@param key string
---@param unlocked boolean
function sessions.setUnlock(citizenid, key, unlocked)
    sessions.unlocks(citizenid)[key] = unlocked or nil
    tablets.setUnlock(citizenid, key, unlocked)
end

---@param src integer
---@return Viewer?
function sessions.viewer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local data = player.PlayerData

    return {
        job = data.job,
        gang = data.gang,
        isStaff = function(ace)
            return IsPlayerAceAllowed(tostring(src), ace) and exports.qbx_core:IsOptin(src) == true
        end,
        unlocks = sessions.unlocks(data.citizenid),
    }
end

---The apps this player sees right now.
---@param src integer
---@return table[]
function sessions.apps(src)
    local viewer = sessions.viewer(src)

    return viewer and apps.visible(viewer) or {}
end

---A notification as the page shows it, with its app's name and icon (and hidden apps flagged).
---@param note Note
---@return table
function sessions.toClient(note)
    local app = note.app and apps.get(note.app)

    return {
        id = note.id,
        app = note.app,
        appLabel = app and app.label or 'iFruit',
        icon = app and app.icon or nil,
        hidden = app and app.access and app.access.unlock ~= nil or false,
        title = note.title,
        body = note.body,
        time = note.time,
        banner = note.banner,
        open = note.open,
    }
end

---@param citizenid string
---@return table[]
function sessions.notes(citizenid)
    local list = {}

    for i, note in ipairs(notifications.list(citizenid)) do
        list[i] = sessions.toClient(note)
    end

    return list
end

---Sends the app list again to everyone with an unlocked tablet open (an app was added or removed).
function sessions.refreshAll()
    for src, session in pairs(open) do
        if session.unlocked then
            TriggerClientEvent('city_os:client:apps', src, sessions.apps(src), notifications.badges(session.citizenid))
        end
    end
end

---@param src integer
function sessions.refresh(src)
    local session = open[src]

    if session and session.unlocked then
        TriggerClientEvent('city_os:client:apps', src, sessions.apps(src), notifications.badges(session.citizenid))
    end
end

---@param citizenid string
---@return integer? src of that character, if online with a tablet open
function sessions.findOpen(citizenid)
    for src, session in pairs(open) do
        if session.citizenid == citizenid then return src end
    end
end

return sessions
