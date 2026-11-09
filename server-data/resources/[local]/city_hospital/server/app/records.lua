-- The EMS app's history: every revive and every bill an EMS gave a patient, for the Records tab and the dashboard.

local records = {}

local DAY = 86400

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_hospital_records` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(10) NOT NULL,
            `patient` VARCHAR(100) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `amount` INT UNSIGNED NOT NULL DEFAULT 0,
            `note` VARCHAR(80) NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `created` (`created`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

---@param player table
---@return string
local function fullName(player)
    local info = player.PlayerData.charinfo

    return ('%s %s'):format(info.firstname, info.lastname)
end

---Writes one revive or bill. `src` is the EMS, `target` the patient.
---@param kind 'revive' | 'bill'
---@param src integer
---@param target integer
---@param amount? integer
---@param note? string
function records.add(kind, src, target, amount, note)
    local ems = exports.qbx_core:GetPlayer(src)
    local patient = exports.qbx_core:GetPlayer(target)
    if not ems or not patient then return end

    MySQL.insert('INSERT INTO city_hospital_records (kind, patient, citizenid, name, amount, note, created) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        kind, fullName(patient):sub(1, 100), ems.PlayerData.citizenid, fullName(ems):sub(1, 100), math.max(0, amount or 0),
        type(note) == 'string' and note ~= '' and note:sub(1, 80) or nil, os.time(),
    })
end

---Newest first.
---@param limit integer
---@return table[]
function records.recent(limit)
    return MySQL.query.await('SELECT id, kind, patient, name, amount, note, created FROM city_hospital_records ORDER BY id DESC LIMIT ?', { limit }) or {}
end

---Midnight today, server time.
---@return integer
local function today()
    local now = os.date('*t')

    return os.time({ year = now.year, month = now.month, day = now.day, hour = 0 })
end

---What the dashboard shows: today, the last 7 days per day, the viewer's week, and records per member this week.
---@param citizenid string
---@return table
function records.stats(citizenid)
    local start = today()
    local weekStart = start - 6 * DAY
    local rows = MySQL.query.await('SELECT kind, citizenid, amount, created FROM city_hospital_records WHERE created >= ?', { weekStart }) or {}

    local days = {}
    for i = 0, 6 do
        days[i + 1] = { label = os.date('%a', weekStart + i * DAY), value = 0 }
    end

    local stats = { revivesToday = 0, billedToday = 0, weekCount = 0, mine = 0, byMember = {}, days = days }

    for _, row in ipairs(rows) do
        local index = math.floor((row.created - weekStart) / DAY) + 1

        if days[index] then
            days[index].value = days[index].value + 1
            stats.weekCount = stats.weekCount + 1
            stats.byMember[row.citizenid] = (stats.byMember[row.citizenid] or 0) + 1

            if row.citizenid == citizenid then stats.mine = stats.mine + 1 end

            if row.created >= start then
                if row.kind == 'revive' then stats.revivesToday = stats.revivesToday + 1 end
                if row.kind == 'bill' then stats.billedToday = stats.billedToday + row.amount end
            end
        end
    end

    return stats
end

return records
