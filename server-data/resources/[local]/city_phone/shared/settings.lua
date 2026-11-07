-- The phone settings a player can change, with their allowed values. Used on the server to check what the client sends.
local settings = {}

local function oneOf(list)
    local set = {}
    for i = 1, #list do set[list[i]] = true end

    return function(value) return set[value] == true end
end

local function boolean(value)
    return value == true or value == false
end

local function percent(limits)
    return function(value)
        return type(value) == 'number' and value == math.floor(value) and value >= limits.min and value <= limits.max
    end
end

local RULES = {
    theme = oneOf(Config.Themes),
    language = oneOf(Config.Languages),
    font = oneOf(Config.Fonts),
    wallpaper = oneOf(Config.Wallpapers),
    ringtone = oneOf(Config.Ringtones),
    brightness = percent(Config.Brightness),
    size = percent(Config.Size),
    silent = boolean,
    dnd = boolean,
}

local DEFAULTS = {
    theme = Config.Themes[1],
    language = Config.Languages[1],
    font = Config.Fonts[1],
    wallpaper = Config.Wallpapers[1],
    ringtone = Config.Ringtones[1],
    brightness = Config.Brightness.max,
    size = 100,
    silent = false,
    dnd = false,
}

---@param key unknown
---@param value unknown
---@return boolean
function settings.valid(key, value)
    local rule = type(key) == 'string' and RULES[key]

    return rule ~= nil and rule ~= false and rule(value)
end

---The saved settings with anything missing or invalid set back to its default
---@param saved table?
---@return table
function settings.clean(saved)
    local out = {}

    for key, default in pairs(DEFAULTS) do
        local value = type(saved) == 'table' and saved[key]
        if value ~= nil and settings.valid(key, value) then out[key] = value else out[key] = default end
    end

    return out
end

return settings
