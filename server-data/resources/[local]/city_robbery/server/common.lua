-- Shared server helpers: who is acting, police on duty, staff, distances and the one robbery each player may have going
local common = {}

local sessions = {}

---@param src integer
---@return boolean
function common.isDown(src)
    return GetResourceState('city_hospital') == 'started' and exports.city_hospital:IsDown(src) or false
end

---@return integer
function common.policeOnDuty()
    local count = exports.qbx_core:GetDutyCountJob(Config.PoliceJob)

    return tonumber(count) or 0
end

---@param src integer
---@return boolean
function common.isStaff(src)
    return IsPlayerAceAllowed(tostring(src), Config.StaffAce)
end

---@param value any
---@return vector3?
function common.toVec(value)
    if type(value) ~= 'vector3' and type(value) ~= 'vector4' and type(value) ~= 'table' then return end

    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return end

    return vec3(x, y, z)
end

---@param src integer
---@param coords vector3
---@param maxDistance number
---@return boolean
function common.near(src, coords, maxDistance)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= maxDistance
end

---The robbery this player has going, dropped once it is older than its own time limit.
---@param src integer
---@return table?
function common.session(src)
    local session = sessions[src]
    if session and GetGameTimer() > session.expires then
        sessions[src] = nil
        return
    end

    return session
end

---@param src integer
---@param data table kind, plus anything the robbery needs; ttl in ms
function common.start(src, data)
    data.started = GetGameTimer()
    data.expires = data.started + data.ttl
    sessions[src] = data
end

---@param src integer
function common.stop(src)
    sessions[src] = nil
end

---@param session table
---@param seconds number
---@return boolean
function common.waited(session, seconds)
    -- A second of slack for the network
    return GetGameTimer() - session.started >= (seconds - 1) * 1000
end

---@param src integer
---@param reason string
function common.warn(src, reason)
    lib.print.warn(('city_robbery: player %s %s'):format(src, reason))
end

---Refuses a robbery step: logged with the reason (so staff can see why in the console) and sent to the client.
---@param src integer
---@param reason string locale key shown to the player
---@param detail? string extra detail for the log
---@return false, string
function common.deny(src, reason, detail)
    lib.print.info(('city_robbery: refused player %s (%s): %s%s'):format(src, GetPlayerName(src) or '?', reason, detail and (' - ' .. detail) or ''))

    return false, reason
end

lib.callback.register('city_robbery:cancel', function(source)
    sessions[source] = nil
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

return common
