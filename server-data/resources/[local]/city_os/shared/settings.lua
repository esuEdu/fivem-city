-- Tablet settings: the defaults and the checks applied to anything the page sends, on both sides.

local settings = {}

local ENUMS = {
    appearance = { dark = true, light = true },
    iconStyle = { color = true, clear = true, tinted = true },
    textSize = { small = true, default = true, large = true },
}

local SWITCHES = { 'labels', 'widgets', 'badges', 'lockNotes', 'bold', 'motion' }

local MAX_DOCK_ID = 32

---@param id unknown
---@return boolean
function settings.isAppId(id)
    return type(id) == 'string' and #id <= MAX_DOCK_ID and id:match('^[%w_%-]+$') ~= nil
end

---@param id unknown
---@return boolean
local function isWallpaper(id)
    if id == 'custom' then return true end

    for _, wallpaper in ipairs(Config.Wallpapers) do
        if wallpaper.id == id then return true end
    end

    return false
end

---@param id unknown
---@return table? color from Config.DeviceColors
function settings.deviceColor(id)
    for _, color in ipairs(Config.DeviceColors) do
        if color.id == id then return color end
    end
end

---Settings with every unknown or invalid value replaced by the default.
---@param input unknown
---@return table
function settings.sanitize(input)
    input = type(input) == 'table' and input or {}

    local result = {}

    for key, value in pairs(Config.DefaultSettings) do
        result[key] = value
    end

    if isWallpaper(input.wallpaper) then result.wallpaper = input.wallpaper end
    if settings.deviceColor(input.deviceColor) then result.deviceColor = input.deviceColor end

    for key, allowed in pairs(ENUMS) do
        if allowed[input[key]] then result[key] = input[key] end
    end

    for _, key in ipairs(SWITCHES) do
        if type(input[key]) == 'boolean' then result[key] = input[key] end
    end

    -- App ids in order; unknown ids are fine (the app may come back), duplicates are not
    result.dock = {}
    local seen = {}

    if type(input.dock) == 'table' then
        for _, id in ipairs(input.dock) do
            if #result.dock >= Config.DockSize then break end

            if settings.isAppId(id) and not seen[id] then
                seen[id] = true
                result.dock[#result.dock + 1] = id
            end
        end
    end

    -- Apps whose notifications are turned off
    result.muted = {}

    if type(input.muted) == 'table' then
        for id, value in pairs(input.muted) do
            if settings.isAppId(id) and value == true then result.muted[id] = true end
        end
    end

    return result
end

---A picture link the player may use as wallpaper: plain https, nothing that could end a CSS url() or add markup.
---@param url unknown
---@return boolean
function settings.isWallpaperUrl(url)
    return type(url) == 'string' and #url <= 480 and url:match('^https://[^%s"\'()\\<>]+$') ~= nil and #url > 12
end

---@param code unknown
---@return boolean
function settings.isCode(code)
    return type(code) == 'string' and code:match('^%d%d%d%d$') ~= nil
end

return settings
