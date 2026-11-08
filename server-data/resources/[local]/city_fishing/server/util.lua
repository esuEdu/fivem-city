-- Small helpers the server files share.
local gear = require 'shared.gear'

local util = {}

---@param src integer
---@return table? player
---@return string? citizenid
function util.player(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    return player, player.PlayerData.citizenid
end

---@param src integer
---@param coords vector3
---@param range number
---@return boolean
function util.near(src, coords, range)
    local ped = GetPlayerPed(src)

    return ped ~= 0 and #(GetEntityCoords(ped) - coords.xyz) <= range
end

---@param src integer
---@param key string
---@param kind? string
---@param ... any locale arguments
function util.notify(src, key, kind, ...)
    exports.qbx_core:Notify(src, locale(key, ...), kind or 'inform')
end

---@param src integer
---@return string name "First Last"
function util.name(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return '?' end

    local charinfo = player.PlayerData.charinfo

    return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
end

---Whether the player carries a fishing licence of their own that hasn't expired.
---@param src integer
---@param citizenid string
---@return boolean valid
---@return integer? expires
function util.licence(src, citizenid)
    local best

    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, gear.licence.item) or {}) do
        local metadata = slot.metadata or {}

        if metadata.citizenid == citizenid and type(metadata.expires) == 'number' then
            best = math.max(best or 0, metadata.expires)
        end
    end

    return best ~= nil and best > os.time(), best
end

---Takes money for something the server priced: cash first, then bank.
---@param src integer
---@param amount integer
---@param reason string city_economy reason
---@return boolean
function util.pay(src, amount, reason)
    if amount <= 0 then return true end

    if exports.qbx_core:GetMoney(src, 'cash') >= amount then
        return exports.qbx_core:RemoveMoney(src, 'cash', amount, reason) == true
    end

    if exports.qbx_core:GetMoney(src, 'bank') >= amount then
        return exports.qbx_core:RemoveMoney(src, 'bank', amount, reason) == true
    end

    return false
end

---Game hour from Renewed-Weathersync.
---@return integer
function util.hour()
    local time = GlobalState.currentTime

    return type(time) == 'table' and tonumber(time.hour) or 12
end

---Weather type from Renewed-Weathersync ('CLEAR', 'RAIN', ...).
---@return string
function util.weather()
    local weather = GlobalState.weather

    return type(weather) == 'table' and tostring(weather.weather or 'CLEAR') or 'CLEAR'
end

---The rod the player is using: the slot they used, if it still holds a rod.
---@param src integer
---@param slot integer
---@return table? item
---@return table? rod gear.rods entry
function util.rod(src, slot)
    local item = type(slot) == 'number' and exports.city_inventory:GetSlot(src, slot)
    if not item or not gear.rods[item.name] then return end

    return item, gear.rods[item.name]
end

---@param src integer
---@param stat string hunger/thirst
---@param amount number taken off
function util.drain(src, stat, amount)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local current = player.PlayerData.metadata[stat] or 0
    exports.qbx_core:SetMetadata(src, stat, math.max(0, current - amount))
end

return util
