-- Who is a police officer and the checks every server handler uses (job, duty, grade, distance, text).

local police = {}

---@param src integer
---@return table? job
local function jobOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    if job and job.name == Config.Job then return job end
end

---@param src integer
---@return boolean
function police.isCop(src)
    return jobOf(src) ~= nil
end

---@param src integer
---@return boolean
function police.onDuty(src)
    local job = jobOf(src)

    return job ~= nil and job.onduty == true
end

---The officer's grade, or -1 for anyone else.
---@param src integer
---@return integer
function police.grade(src)
    local job = jobOf(src)

    return job and job.grade.level or -1
end

---@param src integer
---@param action string a Config.Permissions key
---@return boolean
function police.can(src, action)
    local lowest = Config.Permissions[action]

    return lowest ~= nil and police.onDuty(src) and police.grade(src) >= lowest
end

---@param player table qbx player
---@return string
function police.fullName(player)
    local info = player.PlayerData.charinfo

    return ('%s %s'):format(info.firstname, info.lastname)
end

---@param src integer
---@return string
function police.name(src)
    local player = exports.qbx_core:GetPlayer(src)

    return player and police.fullName(player) or GetPlayerName(src) or '?'
end

---Cuffed, down or in last stand: a suspect who can't walk away.
---@param src integer
---@return boolean
function police.restrained(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = player and player.PlayerData.metadata
    if not data then return false end

    return data.ishandcuffed == true or data.isdead == true or data.inlaststand == true
end

---@param src integer
---@return string?
function police.citizenid(src)
    local player = exports.qbx_core:GetPlayer(src)

    return player and player.PlayerData.citizenid
end

---@param src integer
---@param coords vector3
---@param distance number
---@return boolean
function police.near(src, coords, distance)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= distance
end

---The player an action is aimed at: a real player other than src, within reach.
---@param src integer
---@param target unknown
---@param distance? number default Config.Ranges.player
---@return integer?
function police.reach(src, target, distance)
    target = math.tointeger(tonumber(target))
    if not target or target == src or not exports.qbx_core:GetPlayer(target) then return end

    if not police.near(src, GetEntityCoords(GetPlayerPed(target)), distance or Config.Ranges.player) then return end

    return target
end

---The closest other player within distance (for usable items, which only know who used them).
---@param src integer
---@param distance number
---@return integer?
function police.closest(src, distance)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local best, bestDistance = nil, distance

    for target in pairs(exports.qbx_core:GetQBPlayers()) do
        if target ~= src then
            local gap = #(GetEntityCoords(GetPlayerPed(target)) - coords)
            if gap <= bestDistance then best, bestDistance = target, gap end
        end
    end

    return best
end

---Server ids of officers on duty.
---@return integer[]
function police.onDutyList()
    local _, list = exports.qbx_core:GetDutyCountJob(Config.Job)

    return list or {}
end

---Sends a client event to every officer on duty.
---@param event string
---@param ... any
function police.toOnDuty(event, ...)
    local list = police.onDutyList()

    for i = 1, #list do
        TriggerClientEvent(event, list[i], ...)
    end
end

---Text from a player: control characters and angle brackets out, trimmed, cut to max.
---@param text unknown
---@param max integer
---@return string
function police.clean(text, max)
    if type(text) ~= 'string' then return '' end

    return (text:gsub('[%c<>]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')):sub(1, max)
end

---Longer text that keeps its line breaks (reports).
---@param text unknown
---@param max integer
---@return string
function police.cleanLong(text, max)
    if type(text) ~= 'string' then return '' end

    return (text:gsub('\r', ''):gsub('[%z\1-\9\11-\31<>]', ' '):match('^%s*(.-)%s*$')):sub(1, max)
end

---@param src integer
---@param reason string
function police.warn(src, reason)
    lib.print.warn(('city_police: %s (%s) %s'):format(GetPlayerName(src) or '?', src, reason))
end

---@param src integer
---@param key string locale key
---@param kind? string
---@param ... any
function police.notify(src, key, kind, ...)
    exports.qbx_core:Notify(src, locale(key, ...), kind or 'inform')
end

return police
