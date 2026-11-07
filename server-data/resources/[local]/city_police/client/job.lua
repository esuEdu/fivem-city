-- Small helpers every client file uses: is this player an officer on duty, the closest player, error messages.

local job = {}

---@return boolean
function job.isCop()
    local current = QBX.PlayerData and QBX.PlayerData.job
    return current ~= nil and current.name == Config.Job
end

---@return boolean
function job.onDuty()
    return job.isCop() and QBX.PlayerData.job.onduty == true
end

---@return integer
function job.grade()
    return job.isCop() and QBX.PlayerData.job.grade.level or -1
end

---The server id of the closest player within distance, or nil.
---@param distance? number
---@return integer?
function job.closestPlayer(distance)
    local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), distance or Config.Ranges.player, false)

    return player and GetPlayerServerId(player) or nil
end

---The server id behind a player ped (ox_target entity).
---@param entity integer
---@return integer
function job.serverIdOf(entity)
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
end

---Shows why the server said no.
---@param reason string?
function job.fail(reason)
    exports.qbx_core:Notify(locale(('error_%s'):format(reason or 'failed')), 'error')
end

---"Zone, Street" for a position (street names exist only on the client).
---@param coords vector3 | { x: number, y: number, z: number }
---@return string
function job.place(coords)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    return zone ~= 'NULL' and ('%s, %s'):format(street, zone) or street
end

return job
