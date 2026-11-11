-- The faction apps' server side: one city_os app per faction (all showing the same page), the wrapper every app
-- callback goes through, and the Dashboard and Activity tabs.
local orgs = require 'server.orgs'
local farm = require 'server.farm'

local core = {}

local function registerApps()
    for gang, faction in pairs(orgs.factions) do
        exports.city_os:RegisterApp({
            id = ('org_%s'):format(gang),
            label = faction.label,
            page = 'web/app/index.html',
            icon = faction.icon,
            access = { gangs = { [gang] = 0 } },
            order = faction.order,
        })
    end
end

registerApps()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApps() end
end)

---Registers lib.callback 'city_orgs:app:<name>' for faction members; `boss` limits it to the leader (isboss grade).
---The handler returns ok, then the result or why not.
---@param name string
---@param handler fun(src: integer, player: table, faction: Faction, data: table): boolean, any
---@param options? { boss: boolean? }
function core.register(name, handler, options)
    local boss = options and options.boss

    lib.callback.register(('city_orgs:app:%s'):format(name), function(source, data)
        local src = source
        local player = exports.qbx_core:GetPlayer(src)
        local faction = player and orgs.playerFaction(player)

        if not faction then
            lib.print.warn(('city_orgs: %s asked the app for %s without a faction'):format(src, name))
            return false, 'no_permission'
        end

        if boss and not player.PlayerData.gang.isboss then
            lib.print.warn(('city_orgs: %s (%s) tried %s without being the leader'):format(GetPlayerName(src), src, name))
            return false, 'no_permission'
        end

        return handler(src, player, faction, type(data) == 'table' and data or {})
    end)
end

---A citizenid from the page: letters and digits only.
---@param value unknown
---@return string?
function core.citizenid(value)
    if type(value) ~= 'string' or #value < 3 or #value > 50 or value:find('[^%w]') then return end

    return value
end

---The farm items of a faction with their inventory labels, for the page.
---@param faction Faction
---@return { name: string, label: string }[]
local function farmItemList(faction)
    local list = {}

    for i = 1, #faction.farmItems do
        local name = faction.farmItems[i]
        local item = exports.city_inventory:Items(name)

        list[i] = { name = name, label = item and item.label or name }
    end

    return list
end

core.register('app', function(_, player, faction)
    local grades = {}

    for level, grade in pairs(Config.Grades) do
        grades[#grades + 1] = { level = level, name = grade.name }
    end

    table.sort(grades, function(a, b) return a.level < b.level end)

    local gang = player.PlayerData.gang

    return true, {
        me = orgs.fullName(player),
        citizenid = player.PlayerData.citizenid,
        faction = faction.label,
        color = faction.color,
        boss = gang.isboss == true,
        gradeLevel = gang.grade.level,
        grade = gang.grade.name,
        grades = grades,
        farmItems = farmItemList(faction),
    }
end)

---@param gang string
---@param limit integer
---@return table[]
function core.latestLog(gang, limit)
    local rows = MySQL.query.await([[SELECT `citizenid`, `action`, `details`, UNIX_TIMESTAMP(`created_at`) AS `created`
        FROM `city_orgs_log` WHERE `gang` = ? ORDER BY `id` DESC LIMIT ?]], { gang, limit }) or {}
    local citizenids = {}

    for _, row in ipairs(rows) do
        citizenids[#citizenids + 1] = row.citizenid
    end

    local names = orgs.names(citizenids)

    for _, row in ipairs(rows) do
        row.name = names[row.citizenid] or row.citizenid
        row.citizenid = nil
    end

    return rows
end

core.register('dashboard', function(_, player, faction)
    local rows = farm.progressRows(faction.gang, faction, 'weekly', nil)
    local weekNet, mine = 0, nil

    for _, row in ipairs(rows) do
        weekNet = weekNet + row.net
        if row.citizenid == player.PlayerData.citizenid then mine = row end
    end

    local online = {}

    for _, member in pairs(orgs.onlineMembers(faction.gang)) do
        local gang = member.PlayerData.gang
        online[#online + 1] = { name = orgs.fullName(member), grade = gang.grade.name }
    end

    table.sort(online, function(a, b) return a.name < b.name end)

    return true, {
        members = #rows,
        online = online,
        balance = exports.city_bank:OrgBalance(faction.gang, faction.label) or 0,
        weekNet = weekNet,
        mine = mine and { net = mine.net, deposited = mine.deposited, withdrawn = mine.withdrawn } or { net = 0, deposited = 0, withdrawn = 0 },
        days = farm.days(faction.gang),
        latest = core.latestLog(faction.gang, 6),
    }
end)

core.register('activity', function(_, _, faction)
    return true, core.latestLog(faction.gang, 50)
end)

return core
