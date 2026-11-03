local storage = {}

local ready = promise.new()

local SAVE_QUERY = 'INSERT INTO `city_inventories` (`owner`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)'

function storage.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_inventories` (
            `owner` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    ready:resolve()
end

---@param owner string
---@return table[]? entries nil for a new character
function storage.load(owner)
    Citizen.Await(ready)

    local data = MySQL.scalar.await('SELECT `data` FROM `city_inventories` WHERE `owner` = ?', { owner })

    return data and json.decode(data) or nil
end

---Saves several inventories in one batch.
---@param rows { owner: string, entries: table[] }[]
---@param wait? boolean false while the resource is stopping, when we can't yield
function storage.save(rows, wait)
    if #rows == 0 then return end

    local params = {}

    for i = 1, #rows do
        params[i] = { rows[i].owner, json.encode(rows[i].entries) }
    end

    if wait == false then
        MySQL.prepare(SAVE_QUERY, params)
    else
        MySQL.prepare.await(SAVE_QUERY, params)
    end
end

return storage
