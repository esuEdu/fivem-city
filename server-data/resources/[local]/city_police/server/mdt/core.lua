-- The wrapper every MDT callback goes through: the officer must be on duty with the grade Config.Permissions asks.

local police = require 'server.police'

local mdt = {}

---Registers lib.callback 'city_police:mdt:<name>'. The handler returns ok, then the result or why not.
---@param name string
---@param handler fun(src: integer, data: table): boolean, any
---@param permission? string | string[] Config.Permissions key, or several where any one is enough (default: name)
function mdt.register(name, handler, permission)
    local permissions = type(permission) == 'table' and permission or { permission or name }

    lib.callback.register(('city_police:mdt:%s'):format(name), function(source, data)
        local src = source
        if not exports.qbx_core:GetPlayer(src) then return false, 'no_player' end

        if not police.onDuty(src) then return false, 'off_duty' end

        local allowed = false
        for _, key in ipairs(permissions) do
            if police.can(src, key) then
                allowed = true
                break
            end
        end

        if not allowed then
            police.warn(src, ('tried MDT %s without the grade'):format(name))
            return false, 'no_permission'
        end

        return handler(src, type(data) == 'table' and data or {})
    end)
end

---Every permission and whether this officer has it, for the page to hide what it can't do.
---@param src integer
---@return table<string, boolean>
function mdt.permissions(src)
    local list = {}

    for action in pairs(Config.Permissions) do
        list[action] = police.can(src, action)
    end

    return list
end

---A citizen id from the page: letters and digits only.
---@param value unknown
---@return string?
function mdt.citizenid(value)
    if type(value) ~= 'string' or #value < 3 or #value > 50 or value:find('[^%w]') then return end

    return value
end

---A plate from the page, upper case, as qbx stores them (trimmed).
---@param value unknown
---@return string?
function mdt.plate(value)
    if type(value) ~= 'string' then return end

    value = value:upper():match('^%s*(.-)%s*$')
    if #value < 1 or #value > 8 or value:find('[^%w ]') then return end

    return value
end

---A positive integer id from the page.
---@param value unknown
---@return integer?
function mdt.id(value)
    value = math.tointeger(value)

    return value and value > 0 and value or nil
end

---Search text: at least 2 characters, LIKE wildcards escaped.
---@param value unknown
---@return string?
function mdt.like(value)
    if type(value) ~= 'string' then return end

    value = value:match('^%s*(.-)%s*$'):sub(1, 40)
    if #value < 2 then return end

    return ('%%%s%%'):format((value:gsub('[%%_\\]', '\\%0')))
end

---A character's name and basic info from the players table (online or not).
---@param citizenid string
---@return table? player { citizenid, name, charinfo, metadata, job, online }
function mdt.person(citizenid)
    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)

    if online then
        local data = online.PlayerData
        return { citizenid = citizenid, name = police.fullName(online), charinfo = data.charinfo, metadata = data.metadata, job = data.job, source = data.source }
    end

    local row = MySQL.single.await('SELECT charinfo, metadata, job FROM players WHERE citizenid = ?', { citizenid })
    if not row then return end

    local charinfo = json.decode(row.charinfo or '{}') or {}

    return {
        citizenid = citizenid,
        name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or ''),
        charinfo = charinfo,
        metadata = json.decode(row.metadata or '{}') or {},
        job = json.decode(row.job or '{}') or {},
    }
end

return mdt
