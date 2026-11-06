-- Who is staff, what they may do, and the wrapper every staff callback goes through.

local rules = require 'shared.rules'
local log = require 'server.log'

local staff = {}

---A player's staff level from their ACEs; the console is the highest.
---@param src integer
---@return integer
function staff.rank(src)
    if src == 0 then return #Config.Levels + 1 end

    return rules.levelOf(function(ace)
        return IsPlayerAceAllowed(tostring(src), ace)
    end)
end

---@param src integer
---@param action string
---@return boolean
function staff.can(src, action)
    return rules.can(staff.rank(src), action)
end

---Online staff who may do an action.
---@param action string
---@return integer[]
function staff.online(action)
    local list = {}

    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        if staff.can(src, action) then list[#list + 1] = src end
    end

    return list
end

---Registers lib.callback 'city_staff:<name>', run only for staff with `permission` (default: name).
---The handler returns ok, then the result or why not.
---@param name string
---@param handler fun(src: integer, data: table): boolean, any
---@param permission? string
function staff.register(name, handler, permission)
    permission = permission or name

    lib.callback.register(('city_staff:%s'):format(name), function(source, data)
        local src = source
        if not exports.qbx_core:GetPlayer(src) then return false, 'no_player' end

        if not staff.can(src, permission) then
            lib.print.warn(('city_staff: %s (%s) tried %s without permission'):format(GetPlayerName(src), src, name))
            return false, 'no_permission'
        end

        return handler(src, type(data) == 'table' and data or {})
    end)
end

---The player an action is aimed at, checked. Options: notSelf, outrank (the target must be below the staff member).
---@param src integer
---@param data table
---@param options? { notSelf: boolean?, outrank: boolean? }
---@return integer? target
---@return string? reason
function staff.target(src, data, options)
    local target = rules.toId(data.target)
    if not target or not exports.qbx_core:GetPlayer(target) then return nil, 'no_player' end

    options = options or {}
    if options.notSelf and target == src then return nil, 'self' end
    if options.outrank and target ~= src and staff.rank(target) >= staff.rank(src) then return nil, 'outranked' end

    return target
end

staff.log = log.add
staff.who = log.who

return staff
