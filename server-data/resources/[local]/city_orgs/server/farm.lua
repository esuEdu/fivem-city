-- The farm counters and goals. Every item a member puts in or takes out of their faction's vault is counted per
-- item per day; progress toward a goal is always deposited - withdrawn, and both numbers are shown in the app so
-- everyone can spot someone cycling the same items in and out.
local orgs = require 'server.orgs'
local rules = require 'shared.goals'

local farm = {}

---@type table<string, table<string, true>> gang -> farm items
local farmSet = {}

for gang, faction in pairs(orgs.factions) do
    local set = {}

    for i = 1, #faction.farmItems do
        set[faction.farmItems[i]] = true
    end

    farmSet[gang] = set
end

AddEventHandler('city_inventory:server:stashMoved', function(move)
    if type(move) ~= 'table' or type(move.stash) ~= 'string' then return end

    local gang = move.stash:match('^org:(.+)$')
    local faction = gang and orgs.faction(gang)
    if not faction then return end

    local into = move.direction == 'in'

    orgs.log(gang, move.citizenid, into and 'vault_in' or 'vault_out', ('%s x%d'):format(move.name, move.count))

    if farmSet[gang][move.name] then
        -- The column is our own string, never the player's
        local column = into and 'deposited' or 'withdrawn'

        MySQL.query(([[INSERT INTO `city_orgs_farm` (`gang`, `citizenid`, `item`, `day`, `%s`) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `%s` = `%s` + ?]]):format(column, column, column),
            { gang, move.citizenid, move.name, orgs.today(), move.count, move.count })
    end

    orgs.refresh(gang, 'data')
end)

---Summed counters since a day, per member per item.
---@param gang string
---@param fromDay string
---@return table<string, table<string, { deposited: integer, withdrawn: integer }>>
function farm.totals(gang, fromDay)
    local rows = MySQL.query.await([[SELECT `citizenid`, `item`, SUM(`deposited`) AS `deposited`, SUM(`withdrawn`) AS `withdrawn`
        FROM `city_orgs_farm` WHERE `gang` = ? AND `day` >= ? GROUP BY `citizenid`, `item`]], { gang, fromDay }) or {}
    local totals = {}

    for _, row in ipairs(rows) do
        totals[row.citizenid] = totals[row.citizenid] or {}
        totals[row.citizenid][row.item] = { deposited = tonumber(row.deposited) or 0, withdrawn = tonumber(row.withdrawn) or 0 }
    end

    return totals
end

---@param gang string
---@param period 'daily' | 'weekly'
---@return string first day that counts
function farm.periodStart(gang, period)
    return period == 'daily' and orgs.today() or orgs.weekStart()
end

---A member's net over their faction's farm items.
---@param faction Faction
---@param counters table<string, { deposited: integer, withdrawn: integer }>?
---@return integer net
---@return integer deposited
---@return integer withdrawn
function farm.net(faction, counters)
    local deposited, withdrawn = 0, 0

    for i = 1, #faction.farmItems do
        local counted = counters and counters[faction.farmItems[i]]

        if counted then
            deposited = deposited + counted.deposited
            withdrawn = withdrawn + counted.withdrawn
        end
    end

    return deposited - withdrawn, deposited, withdrawn
end

---The goals the leader set.
---@param gang string
---@return table<string, FarmGoal> period -> goal
function farm.goals(gang)
    local rows = MySQL.query.await([[SELECT `period`, `mode`, `amount`, `items` FROM `city_orgs_goals` WHERE `gang` = ?]], { gang }) or {}
    local list = {}

    for _, row in ipairs(rows) do
        list[row.period] = { mode = row.mode, amount = row.amount, items = json.decode(row.items) or {} }
    end

    return list
end

---@param gang string
---@param period 'daily' | 'weekly'
---@param goal FarmGoal
function farm.setGoal(gang, period, goal)
    MySQL.query.await([[INSERT INTO `city_orgs_goals` (`gang`, `period`, `mode`, `amount`, `items`) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `mode` = VALUES(`mode`), `amount` = VALUES(`amount`), `items` = VALUES(`items`)]],
        { gang, period, goal.mode, goal.amount, json.encode(goal.items) })
end

---@param gang string
---@param period 'daily' | 'weekly'
function farm.clearGoal(gang, period)
    MySQL.query.await([[DELETE FROM `city_orgs_goals` WHERE `gang` = ? AND `period` = ?]], { gang, period })
end

---Every member's progress for one period, sorted by net (the contribution ranking). Without a goal the rows still
---carry the counters, so the ranking works before the leader sets anything.
---@param gang string
---@param faction Faction
---@param period 'daily' | 'weekly'
---@param goal FarmGoal?
---@return table[]
function farm.progressRows(gang, faction, period, goal)
    local totals = farm.totals(gang, farm.periodStart(gang, period))
    local members = exports.qbx_core:GetGroupMembers(gang, 'gang') or {}
    local citizenids = {}
    local rows = {}

    for _, member in ipairs(members) do
        citizenids[#citizenids + 1] = member.citizenid

        local counters = totals[member.citizenid] or {}
        local row = { citizenid = member.citizenid, grade = member.grade }

        if goal then
            local progress = rules.progress(goal, counters)
            row.deposited, row.withdrawn, row.net = progress.deposited, progress.withdrawn, progress.net
            row.percent, row.complete, row.items = progress.percent, progress.complete, progress.items
        else
            row.net, row.deposited, row.withdrawn = farm.net(faction, counters)
        end

        rows[#rows + 1] = row
    end

    local names = orgs.names(citizenids)

    for _, row in ipairs(rows) do
        row.name = names[row.citizenid] or row.citizenid
    end

    table.sort(rows, function(a, b)
        if a.net ~= b.net then return a.net > b.net end
        return a.name < b.name
    end)

    return rows
end

---Items put in per day over the last 7 days, for the dashboard chart.
---@param gang string
---@return { label: string, value: integer }[]
function farm.days(gang)
    local now = os.time()
    local first = os.date('%Y-%m-%d', now - 6 * 86400)
    local rows = MySQL.query.await([[SELECT `day`, SUM(`deposited`) AS `deposited` FROM `city_orgs_farm`
        WHERE `gang` = ? AND `day` >= ? GROUP BY `day`]], { gang, first }) or {}
    local byDay = {}

    for _, row in ipairs(rows) do
        -- oxmysql returns DATE columns as timestamps or strings depending on the column; normalize to YYYY-MM-DD
        local day = type(row.day) == 'string' and row.day:sub(1, 10) or os.date('%Y-%m-%d', math.floor((tonumber(row.day) or 0) / 1000))
        byDay[day] = (byDay[day] or 0) + (tonumber(row.deposited) or 0)
    end

    local days = {}

    for i = 6, 0, -1 do
        local stamp = now - i * 86400
        days[#days + 1] = { label = os.date('%a', stamp), value = byDay[os.date('%Y-%m-%d', stamp)] or 0 }
    end

    return days
end

return farm
