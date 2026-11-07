-- Notes: each character's own notes, saved in the database. Pinned notes come first.
local MAX_NOTES = 100
local MAX_TITLE = 60
local MAX_BODY = 5000

local ready = promise.new()

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_notes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `title` VARCHAR(80) NOT NULL DEFAULT '',
            `body` TEXT NOT NULL,
            `pinned` TINYINT(1) NOT NULL DEFAULT 0,
            `updated_at` INT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end)

local last = {}

---@return string? citizenid
local function owner(src, throttleKey)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if throttleKey then
        local now = GetGameTimer()
        last[src] = last[src] or {}
        if last[src][throttleKey] and now - last[src][throttleKey] < 300 then return end
        last[src][throttleKey] = now
    end

    Citizen.Await(ready)
    return player.PlayerData.citizenid
end

local function clean(value, limit)
    if type(value) ~= 'string' then return '' end
    return value:gsub('%z', ''):sub(1, limit)
end

lib.callback.register('city_phone_notes:list', function(source)
    local citizenid = owner(source)
    if not citizenid then return end

    local rows = MySQL.query.await('SELECT `id`, `title`, `body`, `pinned`, `updated_at` FROM `phone_notes` WHERE `citizenid` = ? ORDER BY `pinned` DESC, `updated_at` DESC', { citizenid })

    for i = 1, #rows do rows[i].pinned = rows[i].pinned == true or rows[i].pinned == 1 end

    return rows
end)

-- Creating (no id) or updating a note
lib.callback.register('city_phone_notes:save', function(source, note)
    local citizenid = owner(source, 'save')
    if not citizenid or type(note) ~= 'table' then return false end

    local title, body = clean(note.title, MAX_TITLE), clean(note.body, MAX_BODY)
    local id = math.tointeger(note.id)
    local now = os.time()

    if id then
        local changed = MySQL.update.await('UPDATE `phone_notes` SET `title` = ?, `body` = ?, `updated_at` = ? WHERE `id` = ? AND `citizenid` = ?', { title, body, now, id, citizenid })
        return changed > 0 and id or false
    end

    if title == '' and body == '' then return false end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `phone_notes` WHERE `citizenid` = ?', { citizenid }) or 0
    if count >= MAX_NOTES then return false, 'full' end

    return MySQL.insert.await('INSERT INTO `phone_notes` (`citizenid`, `title`, `body`, `updated_at`) VALUES (?, ?, ?, ?)', { citizenid, title, body, now })
end)

lib.callback.register('city_phone_notes:pin', function(source, id, pinned)
    local citizenid = owner(source, 'pin')
    id = math.tointeger(id)
    if not citizenid or not id then return false end

    return MySQL.update.await('UPDATE `phone_notes` SET `pinned` = ? WHERE `id` = ? AND `citizenid` = ?', { pinned == true and 1 or 0, id, citizenid }) > 0
end)

lib.callback.register('city_phone_notes:delete', function(source, id)
    local citizenid = owner(source, 'delete')
    id = math.tointeger(id)
    if not citizenid or not id then return false end

    return MySQL.update.await('DELETE FROM `phone_notes` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid }) > 0
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
