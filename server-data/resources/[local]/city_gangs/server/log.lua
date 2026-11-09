-- The gang log: hires, promotions, firings, and what members made and sold (reported by city_drugs). The Overview's
-- numbers are counted from it.
local log = {}

---The `AND actor = ?` part and its parameters when the numbers are for one member (a nil in a parameter list would end
---the list early, so the filter is only added when there is a citizenid)
---@param params any[]
---@param citizenid? string
---@return string
local function memberFilter(params, citizenid)
    if not citizenid then return '' end

    params[#params + 1] = citizenid

    return ' AND `actor_citizenid` = ?'
end

function log.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_gangs_log` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `gang` VARCHAR(50) NOT NULL,
            `actor_citizenid` VARCHAR(50) NULL,
            `actor_name` VARCHAR(100) NOT NULL,
            `action` VARCHAR(16) NOT NULL,
            `target_citizenid` VARCHAR(50) NULL,
            `target_name` VARCHAR(100) NULL,
            `amount` INT NULL,
            `details` VARCHAR(64) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `gang_time` (`gang`, `created_at`),
            KEY `gang_actor` (`gang`, `actor_citizenid`, `created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

---@param gangName string
---@param actor { citizenid: string?, name: string }
---@param action string hire, promote, demote, fire, leave, sale, made
---@param target? { citizenid: string?, name: string }
---@param amount? integer
---@param details? string
function log.add(gangName, actor, action, target, amount, details)
    MySQL.insert('INSERT INTO `city_gangs_log` (`gang`, `actor_citizenid`, `actor_name`, `action`, `target_citizenid`, `target_name`, `amount`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        gangName, actor.citizenid, actor.name:sub(1, 100), action, target and target.citizenid, target and target.name:sub(1, 100), amount, details and details:sub(1, 64),
    })
end

---@param gangName string
---@param limit integer
---@return table[]
function log.recent(gangName, limit)
    return MySQL.query.await([[
        SELECT `actor_name` AS `actor`, `action`, `target_name` AS `target`, `amount`, `details`, UNIX_TIMESTAMP(`created_at`) AS `time`
        FROM `city_gangs_log` WHERE `gang` = ? ORDER BY `id` DESC LIMIT ?
    ]], { gangName, limit }) or {}
end

---What the gang (or one member, with `citizenid`) made and sold since `since`: totals, per drug and per member
---@param gangName string
---@param since integer unix time
---@param citizenid? string
---@return { sales: integer, earned: integer, made: integer, drugs: table[], members: table<string, { sales: integer, earned: integer, made: integer }> }
function log.stats(gangName, since, citizenid)
    local params = { gangName, since }
    local rows = MySQL.query.await(([[
        SELECT `actor_citizenid` AS `citizenid`, `action`, `details` AS `drug`, COUNT(*) AS `n`, COALESCE(SUM(`amount`), 0) AS `total`
        FROM `city_gangs_log` WHERE `gang` = ? AND `created_at` >= FROM_UNIXTIME(?) AND `action` IN ('sale', 'made')%s
        GROUP BY `actor_citizenid`, `action`, `details`
    ]]):format(memberFilter(params, citizenid)), params) or {}

    local stats = { sales = 0, earned = 0, made = 0, drugs = {}, members = {} }
    local byDrug = {}

    for _, row in ipairs(rows) do
        local n, total = tonumber(row.n) or 0, tonumber(row.total) or 0
        local drug = row.drug or '?'
        local entry = byDrug[drug] or { drug = drug, sales = 0, earned = 0, made = 0 }
        local member = row.citizenid and (stats.members[row.citizenid] or { sales = 0, earned = 0, made = 0 })

        byDrug[drug] = entry
        if member then stats.members[row.citizenid] = member end

        if row.action == 'sale' then
            stats.sales, stats.earned = stats.sales + n, stats.earned + total
            entry.sales, entry.earned = entry.sales + n, entry.earned + total
            if member then member.sales, member.earned = member.sales + n, member.earned + total end
        else
            stats.made = stats.made + total
            entry.made = entry.made + total
            if member then member.made = member.made + total end
        end
    end

    for _, entry in pairs(byDrug) do stats.drugs[#stats.drugs + 1] = entry end
    table.sort(stats.drugs, function(a, b) return a.earned > b.earned end)

    return stats
end

---Money earned and units made per day from `start` (unix) for `days` days, for the whole gang or one member. Days are
---counted from `start` in the database, so the server's and the database's time zones don't matter.
---@param gangName string
---@param start integer
---@param citizenid? string
---@return table[] rows { day, action, total } for rules.series
function log.daily(gangName, start, citizenid)
    local params = { start, gangName, start }

    return MySQL.query.await(([[
        SELECT FLOOR((UNIX_TIMESTAMP(`created_at`) - ?) / 86400) AS `day`, `action`, COALESCE(SUM(`amount`), 0) AS `total`
        FROM `city_gangs_log` WHERE `gang` = ? AND `created_at` >= FROM_UNIXTIME(?) AND `action` IN ('sale', 'made')%s
        GROUP BY `day`, `action`
    ]]):format(memberFilter(params, citizenid)), params) or {}
end

---One member's latest entries (what they did, or what was done to them)
---@param gangName string
---@param citizenid string
---@param limit integer
---@return table[]
function log.member(gangName, citizenid, limit)
    return MySQL.query.await([[
        SELECT `actor_name` AS `actor`, `action`, `target_name` AS `target`, `amount`, `details`, UNIX_TIMESTAMP(`created_at`) AS `time`
        FROM `city_gangs_log` WHERE `gang` = ? AND (`actor_citizenid` = ? OR `target_citizenid` = ?) ORDER BY `id` DESC LIMIT ?
    ]], { gangName, citizenid, citizenid, limit }) or {}
end

return log
