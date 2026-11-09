-- Names for the radio list: a client asks for the players in its own radio channel and gets "callsign name" (the
-- callsign from city_police while on duty). Nobody gets names of a channel they aren't in.

local THROTTLE_MS = 500
local MAX_IDS = 64

local lastAsk = {}

---@param src integer
---@return string
local function displayName(src)
    local player = exports.qbx_core:GetPlayer(src)
    local info = player and player.PlayerData.charinfo
    local name = info and ('%s %s'):format(info.firstname, info.lastname) or GetPlayerName(src) or '?'

    if GetResourceState('city_police') == 'started' then
        local ok, callsign = pcall(function() return exports.city_police:Callsign(src) end)
        if ok and type(callsign) == 'string' and callsign ~= '' then return ('%s %s'):format(callsign, name) end
    end

    return name
end

lib.callback.register('city_radio:names', function(source, ids)
    local src = source
    if not exports.qbx_core:GetPlayer(src) or type(ids) ~= 'table' then return {} end

    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < THROTTLE_MS then return {} end
    lastAsk[src] = now

    local channel = Player(src).state.radioChannel
    if type(channel) ~= 'number' or channel <= 0 then return {} end

    local names = {}

    for i = 1, math.min(#ids, MAX_IDS) do
        local id = math.tointeger(ids[i])

        if id and GetPlayerName(id) and Player(id).state.radioChannel == channel then
            names[tostring(id)] = displayName(id)
        end
    end

    return names
end)

AddEventHandler('playerDropped', function()
    lastAsk[source] = nil
end)

-- Who is in the asking player's own channel (the list after a restart of this resource)
lib.callback.register('city_radio:members', function(source)
    local channel = Player(source).state.radioChannel
    if type(channel) ~= 'number' or channel <= 0 then return {} end

    local ids = {}
    for id in pairs(exports['pma-voice']:getPlayersInRadioChannel(channel) or {}) do ids[#ids + 1] = tonumber(id) end

    return ids
end)
