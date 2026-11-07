-- Clock alarms, saved in the character's metadata (a short list). Times are the player's real local time.
local META_KEY = 'phonealarms'
local MAX_ALARMS = 10
local last = {}

local function player(src)
    local now = GetGameTimer()
    if last[src] and now - last[src] < 250 then return end
    last[src] = now

    return exports.qbx_core:GetPlayer(src)
end

local function integer(value, min, max)
    value = math.tointeger(value)
    return value and value >= min and value <= max and value or nil
end

---The saved alarms, dropping anything that isn't a valid alarm
local function alarmsOf(p)
    local list, out = p.PlayerData.metadata[META_KEY], {}
    if type(list) ~= 'table' then return out end

    for _, alarm in ipairs(list) do
        if type(alarm) == 'table' and integer(alarm.id, 1, 2 ^ 30) and integer(alarm.hour, 0, 23) and integer(alarm.minute, 0, 59) then
            out[#out + 1] = alarm
        end
    end

    return out
end

lib.callback.register('city_phone_clock:alarms', function(source)
    local p = exports.qbx_core:GetPlayer(source)
    return p and alarmsOf(p) or {}
end)

-- Adding (no id) or changing an alarm
lib.callback.register('city_phone_clock:saveAlarm', function(source, data)
    local p = player(source)
    if not p or type(data) ~= 'table' then return false end

    local hour, minute = integer(data.hour, 0, 23), integer(data.minute, 0, 59)
    if not hour or not minute then return false end

    local label = type(data.label) == 'string' and data.label:gsub('%c', ''):sub(1, 30) or ''
    local list = alarmsOf(p)
    local id = integer(data.id, 1, 2 ^ 30)
    local alarm = { hour = hour, minute = minute, label = label, enabled = data.enabled ~= false, repeats = data.repeats == true }

    if id then
        for i, existing in ipairs(list) do
            if existing.id == id then
                alarm.id = id
                list[i] = alarm
            end
        end
        if not alarm.id then return false end
    else
        if #list >= MAX_ALARMS then return false, 'full' end

        local nextId = 1
        for _, existing in ipairs(list) do nextId = math.max(nextId, existing.id + 1) end
        alarm.id = nextId
        list[#list + 1] = alarm
    end

    p.Functions.SetMetaData(META_KEY, list)
    return list
end)

lib.callback.register('city_phone_clock:deleteAlarm', function(source, id)
    local p = player(source)
    id = integer(id, 1, 2 ^ 30)
    if not p or not id then return false end

    local list, kept = alarmsOf(p), {}
    for _, alarm in ipairs(list) do
        if alarm.id ~= id then kept[#kept + 1] = alarm end
    end

    p.Functions.SetMetaData(META_KEY, kept)
    return kept
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
