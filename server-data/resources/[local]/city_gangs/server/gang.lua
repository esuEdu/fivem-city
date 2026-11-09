-- Who is in which gang at what grade, and the wrapper every app callback goes through.
local rules = require 'shared.rules'

local gang = {}

local drugGangs = {}

for _, name in ipairs(Config.Gangs) do drugGangs[name] = true end

---@param name string
---@return boolean
function gang.isDrugGang(name)
    return drugGangs[name] == true
end

---Whether the player has no gang at all (only those can be recruited)
---@param player table qbx player
---@return boolean
function gang.isFree(player)
    local current = player.PlayerData.gang

    return not current or current.name == 'none'
end

---"Firstname Lastname" of a loaded player or a charinfo table
---@param charinfo table?
---@return string
function gang.name(charinfo)
    if type(charinfo) ~= 'table' then return '?' end

    return ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '')
end

---@param player table qbx player
---@return { citizenid: string, name: string }
function gang.who(player)
    return { citizenid = player.PlayerData.citizenid, name = gang.name(player.PlayerData.charinfo) }
end

---The player's drug gang as the callbacks need it, or nil if they aren't in one
---@param player table qbx player
---@return { name: string, label: string, grade: integer, gradeName: string, isboss: boolean, grades: table }?
function gang.of(player)
    local current = player.PlayerData.gang
    if not current or not drugGangs[current.name] then return end

    local definition = exports.qbx_core:GetGang(current.name)
    if not definition then return end

    return {
        name = current.name,
        label = definition.label or current.name,
        grade = current.grade and current.grade.level or 0,
        gradeName = current.grade and current.grade.name or '',
        isboss = current.isboss == true,
        grades = definition.grades,
    }
end

---Registers lib.callback 'city_gangs:<name>', run only for gang members whose grade allows `permission` (default: name).
---The handler gets the source, the player, their gang and the checked data table, and returns ok, then the result or why
---not.
---@param name string
---@param handler fun(src: integer, player: table, group: table, data: table): boolean, any
---@param permission? string
function gang.register(name, handler, permission)
    permission = permission or name

    lib.callback.register(('city_gangs:%s'):format(name), function(source, data)
        local src = source
        local player = exports.qbx_core:GetPlayer(src)
        if not player then return false, 'no_player' end

        local group = gang.of(player)
        if not group then return false, 'no_gang' end

        if not rules.can(Config.Permissions, group.grade, permission) then
            lib.print.warn(('city_gangs: %s (%s) tried %s without permission'):format(GetPlayerName(src), src, name))
            return false, 'no_permission'
        end

        return handler(src, player, group, type(data) == 'table' and data or {})
    end)
end

---@param value unknown
---@return string?
function gang.toCitizenId(value)
    return type(value) == 'string' and #value <= 50 and value:match('^%w+$') and value or nil
end

---@param src integer?
---@param text string
---@param kind? string
function gang.notify(src, text, kind)
    if src then exports.qbx_core:Notify(src, text, kind or 'inform') end
end

return gang
