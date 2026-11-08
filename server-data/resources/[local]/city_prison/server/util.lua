-- Small checks shared by the server files

local util = {}

local last = {}

---@param src integer
---@param coords vector3
---@param distance number
---@return boolean
function util.near(src, coords, distance)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= distance
end

---true when the same action came too soon after the last one
---@param src integer
---@param key string
---@param seconds number
---@return boolean
function util.throttled(src, key, seconds)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < seconds * 1000 then return true end

    byKey[key] = now
    return false
end

---@param player table
---@return string
function util.fullName(player)
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

---@param src integer
---@param key string locale key
---@param kind? string
function util.notify(src, key, kind, ...)
    exports.qbx_core:Notify(src, locale(key, ...), kind or 'inform')
end

function util.warn(src, reason)
    lib.print.warn(('city_prison: %s (%s) %s'):format(GetPlayerName(src) or '?', src, reason))
end

---An on-duty officer's grade, or nil
---@param src integer
---@return integer?
function util.policeGrade(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or job.name ~= Config.PoliceJob or not job.onduty then return end

    return job.grade.level
end

---@return integer
function util.policeOnDuty()
    local count = 0

    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local job = player.PlayerData.job
        if job.name == Config.PoliceJob and job.onduty then count = count + 1 end
    end

    return count
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return util
