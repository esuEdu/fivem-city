-- BOLOs ("be on the lookout"): a person or vehicle to watch for, with no warrant and no known citizen needed. Any
-- officer creates or closes one; a new one notifies every unit on duty. Also the bodycam: watching another unit.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local roster = require 'server.roster'
local settings = require 'server.config'

local KINDS = { person = true, vehicle = true }

---@param value unknown
---@return string?
local function plateOf(value)
    if type(value) ~= 'string' then return end

    local plate = value:upper():gsub('[^%w ]', ''):match('^%s*(.-)%s*$'):sub(1, 8)

    return plate ~= '' and plate or nil
end

mdt.register('bolos', function(_, data)
    local rows

    if data.status == 'closed' then
        rows = MySQL.query.await("SELECT * FROM city_police_bolos WHERE status = 'closed' OR expires <= ? ORDER BY id DESC LIMIT 100", { os.time() })
    else
        rows = MySQL.query.await("SELECT * FROM city_police_bolos WHERE status = 'active' AND expires > ? ORDER BY id DESC LIMIT 100", { os.time() })
    end

    return true, rows or {}
end)

mdt.register('saveBolo', function(src, data)
    local kind = KINDS[data.kind] and data.kind or nil
    local title = police.clean(data.title, settings.text.short)
    local description = police.cleanLong(data.description, settings.text.long)
    local hours = math.tointeger(data.hours) or settings.boloHours
    local plate = kind == 'vehicle' and plateOf(data.plate) or nil

    if not kind or title == '' or description == '' or hours < 1 or hours > 168 then return false, 'invalid' end

    local now = os.time()
    local author = police.name(src)
    local id = MySQL.insert.await('INSERT INTO city_police_bolos (kind, title, description, plate, created_by, created, expires) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        kind, title, description, plate, author, now, now + hours * 3600,
    })
    if not id then return false, 'failed' end

    for _, officer in ipairs(police.onDutyList()) do
        exports.city_os:Notify(officer, {
            app = Config.App.id,
            title = locale('bolo_notify', title),
            body = plate and ('%s · %s'):format(plate, author) or author,
            banner = true,
            open = { tab = 'bolos' },
        })
    end

    return true, id
end, 'bolos')

mdt.register('closeBolo', function(src, data)
    local id = mdt.id(data.id)
    if not id then return false, 'invalid' end

    local changed = MySQL.update.await("UPDATE city_police_bolos SET status = 'closed', closed_by = ?, closed_at = ? WHERE id = ? AND status = 'active'", {
        police.name(src), os.time(), id,
    })

    return changed > 0, changed > 0 and nil or 'not_found'
end, 'bolos')

---@return integer
function mdt.activeBolos()
    return MySQL.scalar.await("SELECT COUNT(*) FROM city_police_bolos WHERE status = 'active' AND expires > ?", { os.time() }) or 0
end

-- Bodycam: another unit on duty, watched live (the viewer's client follows them like a spectator)
mdt.register('bodycam', function(src, data)
    local target = math.tointeger(data.id)
    if not target or target == src or not roster.unit(target) or not police.onDuty(target) then return false, 'not_found' end
    if police.restrained(src) then return false, 'invalid' end

    local unit = roster.unit(target)

    return true, {
        target = target,
        coords = GetEntityCoords(GetPlayerPed(target)),
        label = unit.callsign and ('%s · %s'):format(unit.callsign, unit.name) or unit.name,
    }
end)
