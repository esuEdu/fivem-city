local settings = require 'shared.settings'
local tablets = require 'server.tablets'
local sessions = require 'server.sessions'
local notifications = require 'server.notifications'

-- Settings saves wait this long so a player flicking switches makes one database write
local SAVE_DELAY_MS = 2000

---@type table<string, boolean> serials with a save waiting
local pendingSaves = {}

MySQL.ready(tablets.init)

---@param src integer
---@return table? player
---@return string? reason
local function getPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil, 'busy' end

    local metadata = player.PlayerData.metadata
    if metadata.isdead or metadata.inlaststand or metadata.ishandcuffed then return nil, 'busy' end

    return player
end

---The tablet item the player opens: the one in `slot`, or the one in their lowest slot.
---@param src integer
---@param slot unknown
---@return table? item slot data
local function findTablet(src, slot)
    slot = math.tointeger(slot)

    if slot then
        local item = exports.city_inventory:GetSlot(src, slot)
        return item and item.name == Config.Item and item or nil
    end

    local found

    for _, item in ipairs(exports.city_inventory:GetSlotsWithItem(src, Config.Item) or {}) do
        if not found or item.slot < found.slot then found = item end
    end

    return found
end

---Gives a tablet its serial the first time it's opened.
---@param src integer
---@param item table
---@return string serial
local function ensureSerial(src, item)
    local metadata = type(item.metadata) == 'table' and item.metadata or {}
    local serial = metadata.serial

    if type(serial) == 'string' and serial:match('^IFP%-%d+%-%u+$') then return serial end

    serial = tablets.newSerial()
    metadata.serial = serial
    exports.city_inventory:SetMetadata(src, item.slot, metadata)

    return serial
end

exports.qbx_core:CreateUseableItem(Config.Item, function(source, item)
    TriggerClientEvent('city_os:client:open', source, item.slot)
end)

lib.callback.register('city_os:open', function(source, slot)
    local src = source
    local player, reason = getPlayer(src)
    if not player then return false, reason end

    local item = findTablet(src, slot)
    if not item then return false, 'no_tablet' end

    local data = player.PlayerData
    local tablet = tablets.get(ensureSerial(src, item), data.citizenid)
    local unlocked = tablet.codeHash == nil

    sessions.start(src, { tablet = tablet, citizenid = data.citizenid, unlocked = unlocked })

    return true, {
        serial = tablet.serial,
        settings = tablet.settings,
        hasCode = not unlocked,
        name = ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname),
        citizenid = data.citizenid,
        notifications = sessions.notes(data.citizenid),
        -- A locked tablet gets its apps only after the right code
        apps = unlocked and sessions.apps(src) or nil,
        badges = unlocked and notifications.badges(data.citizenid) or nil,
    }
end)

lib.callback.register('city_os:unlock', function(source, code)
    local src = source
    local session = sessions.get(src)
    if not session then return false, 'closed' end
    if session.unlocked then return true, sessions.apps(src), notifications.badges(session.citizenid) end
    if not settings.isCode(code) then return false, 'wrong_code' end

    -- Tries are counted on the tablet, so closing and reopening it doesn't reset them
    local tablet = session.tablet
    local now = os.time()
    if now < tablet.waitUntil then return false, 'wait', tablet.waitUntil - now end

    if not tablets.checkCode(tablet, code) then
        tablet.tries = tablet.tries + 1

        if tablet.tries >= Config.CodeTries then
            tablet.tries = 0
            tablet.waitUntil = now + Config.CodeWaitSeconds
            lib.print.info(('Player %s entered %d wrong codes for tablet %s'):format(src, Config.CodeTries, session.tablet.serial))
            return false, 'wait', Config.CodeWaitSeconds
        end

        return false, 'wrong_code'
    end

    session.unlocked = true
    tablet.tries = 0

    return true, sessions.apps(src), notifications.badges(session.citizenid)
end)

lib.callback.register('city_os:saveSettings', function(source, input)
    local src = source
    local session = sessions.get(src)
    if not session or not session.unlocked then return false end

    local tablet = session.tablet
    tablet.settings = settings.sanitize(input)

    if not pendingSaves[tablet.serial] then
        pendingSaves[tablet.serial] = true

        SetTimeout(SAVE_DELAY_MS, function()
            pendingSaves[tablet.serial] = nil
            tablets.saveSettings(tablet, tablet.settings)
        end)
    end

    return true, tablet.settings
end)

-- code: four digits to set or change it, false to remove it
lib.callback.register('city_os:setCode', function(source, code)
    local src = source
    local session = sessions.get(src)
    if not session or not session.unlocked then return false end
    if code ~= false and not settings.isCode(code) then return false end

    tablets.setCode(session.tablet, code or nil)

    return true
end)

lib.callback.register('city_os:clearNotifications', function(source)
    local session = sessions.get(source)
    if not session or not session.unlocked then return false end

    notifications.clear(session.citizenid)

    return true
end)

RegisterNetEvent('city_os:server:closed', function()
    sessions.stop(source)
end)

AddEventHandler('playerDropped', function()
    sessions.stop(source)
end)

-- A new job or gang can show or hide apps
AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    sessions.refresh(src)
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(src)
    sessions.refresh(src)
end)
