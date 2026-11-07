local rules = require 'shared.rules'
local log = require 'server.log'
local staff = require 'server.staff'

MySQL.ready(log.init)

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/index.html',
        icon = Config.App.icon,
        access = { staff = Config.Permissions.app },
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

---Jobs or gangs as the app's pickers need them: name, label and grades, sorted by label.
---@param groups table<string, { label: string, grades: table<integer, { name: string }> }>
---@return table[]
local function groupList(groups)
    local list = {}

    for name, group in pairs(groups) do
        local grades = {}

        for level, grade in pairs(group.grades or {}) do
            grades[#grades + 1] = { level = level, name = grade.name }
        end

        table.sort(grades, function(a, b) return a.level < b.level end)
        list[#list + 1] = { name = name, label = group.label or name, grades = grades }
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

-- What the app needs when it opens: what this staff member may do, and the lists its forms use
staff.register('app', function(src)
    local level = staff.rank(src)
    local permissions = rules.permissions(level)

    local player = exports.qbx_core:GetPlayer(src)
    local charinfo = player.PlayerData.charinfo

    return true, {
        me = ('%s %s'):format(charinfo.firstname, charinfo.lastname),
        staffOnline = #staff.online('app'),
        level = Config.Levels[level],
        permissions = permissions,
        banLengths = Config.BanLengths,
        maxBanHours = Config.MaxBanHours,
        maxBucket = Config.MaxBucket,
        jobs = permissions.setJob and groupList(exports.qbx_core:GetJobs()) or nil,
        gangs = permissions.setGang and groupList(exports.qbx_core:GetGangs()) or nil,
    }
end)

staff.register('log', function()
    return true, log.recent(Config.LogLimit)
end)
