-- Small checks shared by the server files
local common = {}

local last = {}

---@param src integer
---@return table? player
---@return string? citizenid
---@return string? number
function common.player(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- The number of the phone in use: their own, or a burner's (city_phone decides)
    return player, player.PlayerData.citizenid, exports.city_phone:ActiveNumber(src)
end

---@param number string
---@return integer? source of the player whose phone answers this number now
function common.online(number)
    return exports.city_phone:SourceByNumber(number)
end

---A burner always calls with a hidden number
---@param src integer
---@return boolean
function common.isBurner(src)
    return exports.city_phone:IsBurner(src)
end

---A number as typed: digits only, within the allowed length
---@param value unknown
---@return string?
function common.number(value)
    if type(value) ~= 'string' and type(value) ~= 'number' then return end

    local digits = tostring(value):gsub('%D', '')
    if #digits < Config.NumberLength.min or #digits > Config.NumberLength.max then return end

    return digits
end

---@param value unknown
---@return string?
function common.name(value)
    if type(value) ~= 'string' then return end

    local name = value:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if #name < 1 then return end

    return name:sub(1, Config.NameLength)
end

---@param src integer
---@return boolean
function common.hasPhone(src)
    return exports.city_phone:HasPhone(src)
end

---true when the same action came too soon after the last one
---@param src integer
---@param key string
---@param ms integer
---@return boolean
function common.throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
