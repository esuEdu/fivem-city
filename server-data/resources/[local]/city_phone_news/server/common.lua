-- Small checks and helpers shared by the server files
local common = {}

local ready = promise.new()
local last = {}

function common.setReady()
    ready:resolve()
end

function common.wait()
    if ready.state == 0 then Citizen.Await(ready) end
end

---@param src integer
---@return table? player
function common.player(src)
    return exports.qbx_core:GetPlayer(src)
end

---@param player table
---@return string
function common.name(player)
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname):sub(1, 60)
end

---What the player may do: write (journalist on duty), boss (deletes any article or comment), staff (same, logged)
---@param src integer
---@return { write: boolean, boss: boolean, staff: boolean }
function common.rights(src)
    local player = common.player(src)
    local job = player and player.PlayerData.job
    local journalist = job ~= nil and Config.Jobs[job.name] == true

    return {
        write = journalist and job.onduty == true,
        boss = journalist and job.isboss == true,
        staff = IsPlayerAceAllowed(tostring(src), Config.StaffAce),
    }
end

---A whole number from the page (JSON numbers can arrive as 5.0)
---@return integer?
function common.int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---Text from the page without control characters or < >; new lines kept when multiline
---@return string?
function common.text(value, max, multiline)
    if type(value) ~= 'string' then return end

    local clean = value:gsub('[\0-\9\11-\31<>]', '')
    if not multiline then clean = clean:gsub('\n', ' ') end

    return clean:match('^%s*(.-)%s*$'):sub(1, max)
end

---true when the same action came too soon after the last one
function common.throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

function common.hasPhone(src)
    return exports.city_inventory:GetItemCount(src, Config.Item) > 0
end

function common.staffLog(src, action, ownerCitizenid, details)
    if GetResourceState('city_staff') ~= 'started' then return end
    exports.city_staff:Log(src, action, { citizenid = ownerCitizenid }, details)
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
