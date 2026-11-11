-- Flagged plates (stolen / wanted), kept in memory as well for quick lookups.

local db = require 'server.db'

local plates = {}

---@type table<string, { status: string, reason: string, by_name: string, created: integer }>
local flagged = {}

---@param plate string
---@return string
local function key(plate)
    return (plate:upper():gsub('%s', ''))
end

---@param plate string
---@return table?
function plates.get(plate)
    return flagged[key(plate)]
end

---@param plate string
---@param status string
---@param reason string
---@param by string
function plates.flag(plate, status, reason, by)
    local row = { status = status, reason = reason, by_name = by, created = os.time() }
    flagged[key(plate)] = row

    MySQL.insert.await('INSERT INTO city_police_plates (plate, status, reason, by_name, created) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE status = VALUES(status), reason = VALUES(reason), by_name = VALUES(by_name), created = VALUES(created)', {
        key(plate), status, reason, by, row.created,
    })
end

---@param plate string
function plates.clear(plate)
    flagged[key(plate)] = nil
    MySQL.update.await('DELETE FROM city_police_plates WHERE plate = ?', { key(plate) })
end

---@return table<string, table>
function plates.all()
    return flagged
end

CreateThread(function()
    db.wait()

    for _, row in ipairs(MySQL.query.await('SELECT * FROM city_police_plates') or {}) do
        flagged[row.plate] = row
    end
end)

return plates
