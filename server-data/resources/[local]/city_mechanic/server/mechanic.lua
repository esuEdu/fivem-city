-- Who counts as a mechanic at work, and distance checks
local mechanic = {}

---@param src integer
---@return table? player
function mechanic.onDuty(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    if job and job.name == Config.Job and job.onduty then return player end
end

---@param src integer
---@param coords vector3
---@param distance number
---@return boolean
function mechanic.near(src, coords, distance)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= distance
end

return mechanic
