-- Phone calls, all decided here: who rings whom, who is in a call, when the voice channel opens. A call has members
-- (talking) and ringing players (not answered yet); up to Config.MaxMembers together. Voice goes through pma-voice
-- call channels, which only this file sets.
local common = require 'server.common'
local store = require 'server.store'

local calls = {}

local CHANNEL_BASE = 50000

local function recent(src, number, direction, duration)
    local _, citizenid = common.player(src)
    if citizenid then store.addRecent(citizenid, number or '', direction, duration or 0) end
end

local function recentMissed(src, number)
    recent(src, number, 'missed', 0)
end

---@class Call
---@field id integer
---@field members table<integer, { number: string, hidden: boolean, since: integer, dialed?: string, answered: boolean }>
---@field ringing table<integer, { from: integer, at: integer, number: string }> number: the caller as shown ('' if hidden)
---@field active boolean voice is on (someone answered)

---@type table<integer, Call>
local active = {}
---@type table<integer, integer> player -> call id
local inCall = {}
---@type table<integer, integer> player -> the voice channel we put them in
local channelOf = {}
local nextId = 0

local function voice(src, channel)
    channelOf[src] = channel

    -- The player may have just left the server
    local ok, err = pcall(exports['pma-voice'].setPlayerCall, exports['pma-voice'], src, channel)
    if not ok then lib.print.warn(('city_phone_calls: voice channel for %s: %s'):format(src, err)) end
end

---A ringing player's part ends without answering: a missed call for them
local function missed(src, ringing)
    exports.city_phone:SetRinging(src, false)
    recentMissed(src, ringing.number)
    TriggerClientEvent('city_phone_calls:client:call', src, false)
    TriggerClientEvent('city_phone_calls:client:missed', src, ringing.number ~= '' and ringing.number or nil)
end

---What one player sees of a call: the others' numbers (unless hidden) and the state
---@param call Call
---@param viewer integer
local function view(call, viewer)
    local people = {}

    for src, member in pairs(call.members) do
        if src ~= viewer then
            people[#people + 1] = { id = src, number = not member.hidden and member.number or nil, ringing = false }
        end
    end

    for src in pairs(call.ringing) do
        if src ~= viewer then
            local _, _, number = common.player(src)
            people[#people + 1] = { id = src, number = number, ringing = true }
        end
    end

    local me = call.members[viewer]

    return {
        id = call.id,
        incoming = call.ringing[viewer] ~= nil,
        status = call.ringing[viewer] and 'incoming' or (call.active and 'active' or 'calling'),
        since = me and me.since or nil,
        people = people,
    }
end

local function everyone(call)
    local list = {}
    for src in pairs(call.members) do list[#list + 1] = src end
    for src in pairs(call.ringing) do list[#list + 1] = src end
    return list
end

local function broadcast(call)
    for _, src in ipairs(everyone(call)) do
        TriggerClientEvent('city_phone_calls:client:call', src, view(call, src))
    end
end

---@param src integer
function calls.viewFor(src)
    local call = active[inCall[src]]
    return call and view(call, src) or nil
end

---@param src integer
---@return Call?
function calls.of(src)
    return active[inCall[src]]
end


local function endCall(call)
    active[call.id] = nil

    for src, ringing in pairs(call.ringing) do
        call.ringing[src] = nil
        inCall[src] = nil
        missed(src, ringing)
    end

    for src, member in pairs(call.members) do
        call.members[src] = nil
        inCall[src] = nil
        voice(src, 0)
        recent(src, member.dialed or member.from, member.dialed and 'out' or 'in', member.answered and os.time() - member.since or 0)
        TriggerClientEvent('city_phone_calls:client:call', src, false)
    end
end

-- A call with one person left and nobody ringing is over
local function settle(call)
    local members = 0
    for _ in pairs(call.members) do members = members + 1 end

    if members <= 1 and next(call.ringing) == nil then return endCall(call) end

    broadcast(call)
end

---Why a number can't be reached right now, or the player to ring
---@return integer? target
---@return string? reason
local function reach(callerSrc, callerNumber, number)
    local src = common.online(number)
    local target = src and exports.qbx_core:GetPlayer(src)
    if not target then return nil, 'unavailable' end

    if src == callerSrc then return nil, 'self' end
    if not common.hasPhone(src) or Player(src).state.isDead then return nil, 'unavailable' end
    if inCall[src] then return nil, 'busy' end

    -- Blocked callers just hear "busy"
    if store.isBlocked(target.PlayerData.citizenid, callerNumber) then return nil, 'busy' end

    return src
end

local function ring(call, src, from)
    local caller = call.members[from]

    call.ringing[src] = { from = from, at = os.time(), number = caller and not caller.hidden and caller.number or '' }
    inCall[src] = call.id
    exports.city_phone:SetRinging(src, true)

    SetTimeout(Config.RingSeconds * 1000, function()
        local ringing = active[call.id] == call and call.ringing[src]
        if not ringing then return end

        call.ringing[src] = nil
        inCall[src] = nil
        missed(src, ringing)

        settle(call)
    end)
end

lib.callback.register('city_phone_calls:dial', function(source, number, hidden)
    local src = source
    local _, _, myNumber = common.player(src)
    number = common.number(number)

    if not myNumber or not number or common.throttled(src, 'dial', 2000) then return false, 'invalid' end
    if inCall[src] then return false, 'in_call' end
    if Player(src).state.isDead or not common.hasPhone(src) then return false, 'invalid' end

    local target, reason = reach(src, myNumber, number)

    if not target then
        recent(src, number, 'out', 0)
        return false, reason
    end

    nextId = nextId + 1

    local call = { id = nextId, members = {}, ringing = {}, active = false }
    call.members[src] = { number = myNumber, hidden = hidden == true or common.isBurner(src), since = os.time(), dialed = number, answered = false }

    active[call.id] = call
    inCall[src] = call.id

    ring(call, target, src)
    broadcast(call)

    return true
end)

-- Adding someone to a call already going (conference)
lib.callback.register('city_phone_calls:add', function(source, number)
    local src = source
    local call = calls.of(src)
    local member = call and call.members[src]
    number = common.number(number)

    if not member or not call.active or not number or common.throttled(src, 'dial', 2000) then return false, 'invalid' end
    if #everyone(call) >= Config.MaxMembers then return false, 'full' end

    local target, reason = reach(src, member.number, number)
    if not target then return false, reason end

    ring(call, target, src)
    broadcast(call)

    return true
end)

lib.callback.register('city_phone_calls:accept', function(source)
    local src = source
    local call = calls.of(src)
    local ringing = call and call.ringing[src]

    if not ringing or Player(src).state.isDead then return false end

    local _, _, myNumber = common.player(src)

    call.ringing[src] = nil
    exports.city_phone:SetRinging(src, false)

    call.members[src] = {
        number = myNumber, hidden = false, since = os.time(), answered = true,
        from = ringing.number,
    }

    -- The first answer opens the voice channel for everyone in the call
    if not call.active then
        call.active = true

        for memberSrc, member in pairs(call.members) do
            member.answered = true
            member.since = os.time()
            voice(memberSrc, CHANNEL_BASE + call.id)
        end
    else
        voice(src, CHANNEL_BASE + call.id)
    end

    broadcast(call)
    return true
end)

---Leaving: hanging up a call, or turning down one that rings
---@param src integer
function calls.leave(src)
    local call = calls.of(src)
    if not call then return end

    if call.ringing[src] then
        local ringing = call.ringing[src]

        -- Turning a call down: in the recents, no "missed" notification
        call.ringing[src] = nil
        inCall[src] = nil
        exports.city_phone:SetRinging(src, false)
        recentMissed(src, ringing.number)
        TriggerClientEvent('city_phone_calls:client:call', src, false)
    else
        local member = call.members[src]

        call.members[src] = nil
        inCall[src] = nil
        voice(src, 0)
        recent(src, member.dialed or member.from, member.dialed and 'out' or 'in', member.answered and os.time() - member.since or 0)
        TriggerClientEvent('city_phone_calls:client:call', src, false)

        -- Nobody answered and the caller hung up: those still ringing stop too
        if not call.active then return endCall(call) end
    end

    settle(call)
end

lib.callback.register('city_phone_calls:hangup', function(source)
    calls.leave(source)
    return true
end)

-- Mute: the others stop hearing this player on their side
lib.callback.register('city_phone_calls:mute', function(source, muted)
    local src = source
    local call = calls.of(src)
    if not call or not call.members[src] or common.throttled(src, 'mute', 300) then return false end

    for memberSrc in pairs(call.members) do
        if memberSrc ~= src then TriggerClientEvent('city_phone_calls:client:muted', memberSrc, src, muted == true) end
    end

    return true
end)

-- Going down, losing the phone or leaving ends your part of the call
AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    if not value then return end

    local src = GetPlayerFromStateBagName(bagName)
    if src and src ~= 0 and inCall[src] then calls.leave(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source

    if inCall[src] then calls.leave(src) end
    channelOf[src] = nil
end)

-- pma-voice lets any client ask for any call channel. Only the channel we set is allowed; joining another (to listen
-- in on someone's call) is undone and logged.
AddStateBagChangeHandler('callChannel', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 or not value or value == 0 then return end

    if value ~= channelOf[src] then
        lib.print.warn(('city_phone_calls: %s joined call channel %s without a call'):format(src, value))
        CreateThread(function() voice(src, channelOf[src] or 0) end)
    end
end)

return calls
