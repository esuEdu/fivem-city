-- Shared server helpers: the faction list, the activity log and the clock the farm counters use.
local orgs = {}

---@type table<string, Faction>
orgs.factions = require('shared.orgs').factions()

---@param gang unknown
---@return Faction?
function orgs.faction(gang)
    return type(gang) == 'string' and orgs.factions[gang] or nil
end

---@param player table
---@return Faction?
function orgs.playerFaction(player)
    local gang = player.PlayerData.gang

    return gang and orgs.faction(gang.name)
end

---@param player table
---@return string
function orgs.fullName(player)
    local info = player.PlayerData.charinfo

    return ('%s %s'):format(info.firstname, info.lastname)
end

---Writes one line to the faction's activity log (the app's Activity tab).
---@param gang string
---@param citizenid string
---@param action string
---@param details string?
function orgs.log(gang, citizenid, action, details)
    MySQL.insert([[INSERT INTO `city_orgs_log` (`gang`, `citizenid`, `action`, `details`) VALUES (?, ?, ?, ?)]],
        { gang, citizenid, action, (details or ''):sub(1, 255) })
end

---@return string 'YYYY-MM-DD'
function orgs.today()
    return os.date('%Y-%m-%d') --[[@as string]]
end

---Monday of the current week, so weekly goals reset Monday 00:00 server time.
---@return string 'YYYY-MM-DD'
function orgs.weekStart()
    local now = os.time()
    local date = os.date('*t', now)
    local daysPast = (date.wday - 2) % 7 -- wday 1 = Sunday

    return os.date('%Y-%m-%d', now - daysPast * 86400) --[[@as string]]
end

---Names of characters, online or not, in one query.
---@param citizenids string[]
---@return table<string, string>
function orgs.names(citizenids)
    local names = {}
    if #citizenids == 0 then return names end

    local marks = ('?,'):rep(#citizenids):sub(1, -2)
    local rows = MySQL.query.await(([[SELECT `citizenid`, `charinfo` FROM `players` WHERE `citizenid` IN (%s)]]):format(marks), citizenids) or {}

    for _, row in ipairs(rows) do
        local info = json.decode(row.charinfo or '{}') or {}
        names[row.citizenid] = ('%s %s'):format(info.firstname or '?', info.lastname or '')
    end

    return names
end

---Online members of a faction: src -> player.
---@param gang string
---@return table<integer, table>
function orgs.onlineMembers(gang)
    local list = {}

    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local playerGang = player.PlayerData.gang
        if playerGang and playerGang.name == gang then list[src] = player end
    end

    return list
end

---Tells every online member's open app to refresh (the page listens per type: 'farm', 'vault', 'team', 'activity').
---@param gang string
---@param kind string
function orgs.refresh(gang, kind)
    for src in pairs(orgs.onlineMembers(gang)) do
        TriggerClientEvent('city_orgs:client:appMessage', src, { type = kind })
    end
end

return orgs
