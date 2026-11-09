-- The service history: every change confirmed in the tuning bay (plate, who, the parts, the value), for the app's
-- Services tab and dashboard.

local catalog = require 'shared.catalog'

local services = {}

local DAY = 86400

-- Readable names for the cart keys that aren't in catalog.parts / performance / paints
local LABELS = {
    wheels = 'Rim type',
    modFrontWheels = 'Front rims',
    modBackWheels = 'Rear rims',
    modCustomTiresF = 'Custom tyres',
    modSmokeEnabled = 'Tyre smoke',
    tyreSmokeColor = 'Tyre smoke color',
    modXenon = 'Xenon',
    xenonColor = 'Xenon color',
    neonEnabled = 'Neon',
    neonColor = 'Neon color',
    windowTint = 'Window tint',
    plateIndex = 'Plate style',
    modHorns = 'Horn',
    modTurbo = 'Turbo',
}

local PERFORMANCE = {}

for _, list in ipairs({ catalog.parts, catalog.paints }) do
    for i = 1, #list do LABELS[list[i].key] = list[i].label end
end

for i = 1, #catalog.performance do PERFORMANCE[catalog.performance[i].key] = catalog.performance[i].label end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_mechanic_services` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(8) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `parts` TEXT NOT NULL,
            `total` INT UNSIGNED NOT NULL DEFAULT 0,
            `repaired` TINYINT(1) NOT NULL DEFAULT 0,
            `staff` TINYINT(1) NOT NULL DEFAULT 0,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `created` (`created`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

---The cart as a short list of readable changes, sorted ("Engine 3", "Spoiler", "Primary").
---@param cart table<string, any>
---@return string[]
function services.describe(cart)
    local list = {}

    for key, value in pairs(cart) do
        if PERFORMANCE[key] then
            list[#list + 1] = value == -1 and ('%s stock'):format(PERFORMANCE[key]) or ('%s %d'):format(PERFORMANCE[key], value + 1)
        elseif key == 'modTurbo' then
            list[#list + 1] = value and 'Turbo' or 'Turbo removed'
        elseif LABELS[key] then
            list[#list + 1] = LABELS[key]
        end
    end

    table.sort(list)

    return list
end

---@param entry { plate: string, citizenid: string, name: string, parts: string[], total: integer, repaired: boolean, staff: boolean }
function services.record(entry)
    MySQL.insert('INSERT INTO city_mechanic_services (plate, citizenid, name, parts, total, repaired, staff, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        entry.plate:match('^%s*(.-)%s*$'):sub(1, 8), entry.citizenid, entry.name:sub(1, 100), json.encode(entry.parts), math.max(0, entry.total),
        entry.repaired and 1 or 0, entry.staff and 1 or 0, os.time(),
    })
end

---@param row table
---@return table
local function toView(row)
    return {
        id = row.id,
        plate = row.plate,
        citizenid = row.citizenid,
        name = row.name,
        parts = json.decode(row.parts) or {},
        total = row.total,
        repaired = row.repaired == 1 or row.repaired == true,
        staff = row.staff == 1 or row.staff == true,
        created = row.created,
    }
end

---Newest first.
---@param limit integer
---@return table[]
function services.recent(limit)
    local rows = MySQL.query.await('SELECT * FROM city_mechanic_services ORDER BY id DESC LIMIT ?', { limit }) or {}

    for i = 1, #rows do rows[i] = toView(rows[i]) end

    return rows
end

---Midnight today, server time.
---@return integer
local function today()
    local now = os.date('*t')

    return os.time({ year = now.year, month = now.month, day = now.day, hour = 0 })
end

---What the dashboard shows: today, the last 7 days per day, the viewer's week, and services per member this week.
---@param citizenid string
---@return table
function services.stats(citizenid)
    local start = today()
    local weekStart = start - 6 * DAY
    local rows = MySQL.query.await('SELECT citizenid, total, created, staff FROM city_mechanic_services WHERE created >= ?', { weekStart }) or {}

    local days = {}
    for i = 0, 6 do
        local dayStart = weekStart + i * DAY
        days[i + 1] = { label = os.date('%a', dayStart), value = 0 }
    end

    local stats = { todayCount = 0, todayValue = 0, weekCount = 0, mine = 0, byMember = {}, days = days }

    for _, row in ipairs(rows) do
        local index = math.floor((row.created - weekStart) / DAY) + 1

        if days[index] then
            days[index].value = days[index].value + 1
            stats.weekCount = stats.weekCount + 1
            stats.byMember[row.citizenid] = (stats.byMember[row.citizenid] or 0) + 1

            if row.citizenid == citizenid then stats.mine = stats.mine + 1 end

            if row.created >= start then
                stats.todayCount = stats.todayCount + 1
                stats.todayValue = stats.todayValue + row.total
            end
        end
    end

    return stats
end

return services
