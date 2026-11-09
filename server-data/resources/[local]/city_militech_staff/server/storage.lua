-- Staff setups of owned cars (player_vehicles.id), cached in memory after the first read
local storage = {}

local cache = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_militech_staff_tunes` (
            `vehicle_id` INT NOT NULL,
            `vals` LONGTEXT NOT NULL,
            `updated_by` VARCHAR(50) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`vehicle_id`)
        )
    ]])
end)

---@param vehicleId integer
---@return table?
function storage.get(vehicleId)
    if cache[vehicleId] ~= nil then return cache[vehicleId] or nil end

    local raw = MySQL.scalar.await('SELECT vals FROM city_militech_staff_tunes WHERE vehicle_id = ?', { vehicleId })
    local values = raw and json.decode(raw)

    if type(values) ~= 'table' or next(values) == nil then values = nil end

    cache[vehicleId] = values or false

    return values
end

---@param vehicleId integer
---@param values table empty to remove the staff setup
---@param citizenid string
function storage.set(vehicleId, values, citizenid)
    if next(values) == nil then
        cache[vehicleId] = false
        MySQL.query('DELETE FROM city_militech_staff_tunes WHERE vehicle_id = ?', { vehicleId })
        return
    end

    cache[vehicleId] = values
    MySQL.query('INSERT INTO city_militech_staff_tunes (vehicle_id, vals, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE vals = VALUES(vals), updated_by = VALUES(updated_by)',
        { vehicleId, json.encode(values), citizenid })
end

return storage
