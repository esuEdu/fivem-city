-- Setups of owned cars (player_vehicles.id), cached in memory after the first read
local storage = {}

local cache = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_militech_tunes` (
            `vehicle_id` INT NOT NULL,
            `settings` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`vehicle_id`)
        )
    ]])
end)

---@param vehicleId integer
---@return table<string, number>?
function storage.get(vehicleId)
    if cache[vehicleId] ~= nil then return cache[vehicleId] or nil end

    local raw = MySQL.scalar.await('SELECT settings FROM city_militech_tunes WHERE vehicle_id = ?', { vehicleId })
    local settings = raw and json.decode(raw)

    if type(settings) ~= 'table' or next(settings) == nil then settings = nil end

    cache[vehicleId] = settings or false

    return settings
end

---@param vehicleId integer
---@param settings table<string, number> empty to go back to stock
function storage.set(vehicleId, settings)
    if next(settings) == nil then
        cache[vehicleId] = false
        MySQL.query('DELETE FROM city_militech_tunes WHERE vehicle_id = ?', { vehicleId })
        return
    end

    cache[vehicleId] = settings
    MySQL.query('INSERT INTO city_militech_tunes (vehicle_id, settings) VALUES (?, ?) ON DUPLICATE KEY UPDATE settings = VALUES(settings)',
        { vehicleId, json.encode(settings) })
end

return storage
