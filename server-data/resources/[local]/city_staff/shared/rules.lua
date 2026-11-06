-- Staff levels, permissions, ban lengths and text checks: plain Lua, so tests run it outside the game.

local rules = {}

-- bans.expire is an INT(11); this far-off time means permanent
rules.PERMANENT = 2147483647

-- Longest ban accepted at all (ten years), even with banLong
local MAX_BAN_HOURS = 87600

---@param name string?
---@return integer level 1.. for a configured level, 0 for none
function rules.levelIndex(name)
    for i, level in ipairs(Config.Levels) do
        if level == name then return i end
    end

    return 0
end

---The highest staff level a player has.
---@param hasAce fun(ace: string): boolean
---@return integer
function rules.levelOf(hasAce)
    for i = #Config.Levels, 1, -1 do
        if hasAce(Config.Levels[i]) then return i end
    end

    return 0
end

---Whether a staff level may do an action. Actions missing from Config.Permissions are off.
---@param level integer
---@param action string
---@return boolean
function rules.can(level, action)
    local needed = rules.levelIndex(Config.Permissions[action])

    return needed > 0 and level >= needed
end

---Every configured action and whether this level may do it, for the app to show only what works.
---@param level integer
---@return table<string, boolean>
function rules.permissions(level)
    local result = {}

    for action in pairs(Config.Permissions) do
        result[action] = rules.can(level, action)
    end

    return result
end

---A ban's length in seconds, or nil and why not. 0 hours = permanent.
---@param hours unknown
---@param canLong boolean may ban longer than Config.MaxBanHours, or permanently
---@return integer? seconds 0 = permanent
---@return string? reason
function rules.banSeconds(hours, canLong)
    hours = math.tointeger(tonumber(hours))
    if not hours or hours < 0 or hours > MAX_BAN_HOURS then return nil, 'invalid' end

    if hours == 0 or hours > Config.MaxBanHours then
        if not canLong then return nil, 'too_long' end
    end

    return hours * 3600
end

---Text from a player or staff member, trimmed and without control characters, or nil if empty or not a string.
---@param text unknown
---@param maxLength integer
---@return string?
function rules.cleanText(text, maxLength)
    if type(text) ~= 'string' then return end

    text = text:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    return text:sub(1, maxLength)
end

---@param value unknown
---@return integer? a non-negative integer
function rules.toId(value)
    local id = math.tointeger(tonumber(value))

    return id and id >= 0 and id or nil
end

return rules
