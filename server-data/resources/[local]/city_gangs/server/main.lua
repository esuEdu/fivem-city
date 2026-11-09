local rules = require 'shared.rules'
local gang = require 'server.gang'
local log = require 'server.log'

lib.locale()

MySQL.ready(log.init)

-- Only the drug gangs (Config.Gangs) see the app, from the grade Config.Permissions.app allows
local function registerApp()
    local gangs = {}

    for _, name in ipairs(Config.Gangs) do
        if exports.qbx_core:GetGang(name) then
            gangs[name] = Config.Permissions.app
        else
            lib.print.warn(('city_gangs: Config.Gangs has %s, which is not a qbx_core gang'):format(name))
        end
    end

    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/index.html',
        icon = Config.App.icon,
        access = { gangs = gangs },
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

-- What the app needs when it opens: who this member is, what their grade may do, and the gang's grades
gang.register('app', function(_, player, group)
    local grades = {}

    for level, grade in pairs(group.grades) do
        grades[#grades + 1] = { level = level, name = grade.name, isboss = grade.isboss == true }
    end

    table.sort(grades, function(a, b) return a.level < b.level end)

    return true, {
        me = gang.name(player.PlayerData.charinfo),
        gang = group.label,
        grade = group.grade,
        gradeName = group.gradeName,
        isboss = group.isboss,
        grades = grades,
        permissions = rules.permissions(Config.Permissions, group.grade),
        inviteDistance = Config.InviteDistance,
        periods = Config.Periods,
        period = Config.StatsDays,
    }
end)

gang.register('log', function(_, _, group)
    return true, log.recent(group.name, Config.LogLimit)
end)

-- The drugs guide comes from city_drugs, which owns the numbers
gang.register('drugs', function()
    if GetResourceState('city_drugs') ~= 'started' then return false, 'unavailable' end

    return true, exports.city_drugs:Guide()
end, 'app')

---Whether a gang is a drug gang (city_drugs lets only these use its labs and bulk deals)
exports('IsDrugGang', function(name)
    return type(name) == 'string' and gang.isDrugGang(name)
end)

---What a member made or sold, from a resource in Config.RecordFrom: { kind = 'sale' | 'made', drug, amount }
exports('Record', function(src, data)
    local resource = GetInvokingResource()
    if not Config.RecordFrom[resource] then
        lib.print.warn(('city_gangs: %s may not record gang activity'):format(tostring(resource)))
        return false
    end

    if type(data) ~= 'table' or (data.kind ~= 'sale' and data.kind ~= 'made') then return false end

    local amount = math.tointeger(data.amount)
    if not amount or amount < 0 or type(data.drug) ~= 'string' then return false end

    local player = exports.qbx_core:GetPlayer(src)
    local group = player and gang.of(player)
    if not group then return false end

    log.add(group.name, gang.who(player), data.kind, nil, amount, data.drug)

    return true
end)
