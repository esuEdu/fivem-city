-- DarkChat's server side. Every callback needs the phone and the encrypted USB. Rooms are found only by name
-- (there is no list of them); a password, if set, is kept hashed. Other players only ever see aliases.
local store = require 'server.store'

local PURGE_MS = 3600000

local last = {}

CreateThread(function()
    store.init()

    while true do
        store.purge()
        Wait(PURGE_MS)
    end
end)

---The caller's citizenid when they have the phone and the USB
---@param src integer
---@return string?
local function user(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if exports.city_inventory:GetItemCount(src, Config.Phone) < 1 or exports.city_inventory:GetItemCount(src, Config.Item) < 1 then return end

    return player.PlayerData.citizenid
end

local function int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

local function throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

---@param value unknown
---@param pattern string allowed characters
---@param limits { min: integer, max: integer }
---@return string?
local function name(value, pattern, limits)
    if type(value) ~= 'string' or #value < limits.min or #value > limits.max or not value:find(pattern) then return end
    return value
end

lib.callback.register('city_phone_darkchat:me', function(source)
    local src = source
    local citizenid = user(src)
    if not citizenid then return end

    return { alias = store.alias(citizenid) or false, rooms = store.rooms(citizenid) }
end)

lib.callback.register('city_phone_darkchat:setAlias', function(source, alias)
    local src = source
    local citizenid = user(src)
    if not citizenid or throttled(src, 'alias', 2000) then return false, 'invalid' end

    alias = name(alias, '^[%w_%-]+$', Config.AliasLength)
    if not alias then return false, 'alias' end

    return store.setAlias(citizenid, alias)
end)

-- Joining a room by name; a name nobody uses yet creates the room (with the password, if one is given)
lib.callback.register('city_phone_darkchat:enter', function(source, roomName, password)
    local src = source
    local citizenid = user(src)
    if not citizenid or throttled(src, 'enter', 1500) then return false, 'invalid' end
    if not store.alias(citizenid) then return false, 'invalid' end

    roomName = type(roomName) == 'string' and name(roomName:lower(), '^[a-z0-9_%-]+$', Config.RoomLength) or nil
    if not roomName then return false, 'room' end

    if password ~= nil and (type(password) ~= 'string' or #password > Config.PasswordLength) then return false, 'invalid' end
    if password == '' then password = nil end

    local room = store.roomByName(roomName)

    if room and store.isMember(room.id, citizenid) then return { id = room.id, created = false } end
    if store.countRooms(citizenid) >= Config.MaxRooms then return false, 'limit' end

    if room then
        -- A wrong password looks the same as a wrong room name
        if room.password and not (password and VerifyPasswordHash(password, room.password)) then return false, 'denied' end
        if not room.password and password then return false, 'denied' end

        store.join(room.id, citizenid)
        return { id = room.id, created = false }
    end

    local id = store.createRoom(roomName, password and GetPasswordHash(password) or nil)
    if not id then return false, 'invalid' end

    store.join(id, citizenid)
    return { id = id, created = true }
end)

lib.callback.register('city_phone_darkchat:leave', function(source, roomId)
    local src = source
    local citizenid = user(src)
    roomId = int(roomId)
    if not citizenid or not roomId then return false end

    return store.leave(roomId, citizenid)
end)

lib.callback.register('city_phone_darkchat:messages', function(source, roomId, before)
    local src = source
    local citizenid = user(src)
    roomId = int(roomId)
    if not citizenid or not roomId or not store.isMember(roomId, citizenid) then return end

    return store.messages(roomId, citizenid, int(before))
end)

lib.callback.register('city_phone_darkchat:send', function(source, roomId, text)
    local src = source
    local citizenid = user(src)
    roomId = int(roomId)
    if not citizenid or not roomId or type(text) ~= 'string' then return false end
    if throttled(src, 'send', Config.MessageCooldown * 1000) then return false, 'slow' end

    text = text:gsub('[%c<>]', ' '):match('^%s*(.-)%s*$'):sub(1, Config.MessageLength)
    if text == '' or not store.isMember(roomId, citizenid) then return false end

    local alias = store.alias(citizenid)
    if not alias then return false end

    store.post(roomId, citizenid, alias, text)

    -- Online members (with the USB) see it at once
    for _, member in ipairs(store.members(roomId)) do
        local player = member ~= citizenid and exports.qbx_core:GetPlayerByCitizenId(member)
        local target = player and player.PlayerData.source

        if target and exports.city_inventory:GetItemCount(target, Config.Item) > 0 then
            TriggerClientEvent('city_phone_darkchat:client:message', target, roomId)
        end
    end

    return true
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
