-- EMS calls: a downed player's SOS (G), 192 calls from the phone (city_dispatch), the radial menu's emergency button
-- and the police "officer down" alert. EMS on duty see the open calls, accept one and get a GPS route; a downed
-- patient sees who is coming (a phone caller only hears that EMS are on the way).
local settings = require 'server.config'
local state = require 'server.state'

local sos = {}

---@class Call
---@field id integer
---@field src integer who needs help
---@field kind 'sos' | 'phone' | 'emergency' | 'officer'
---@field text string
---@field coords vector3
---@field at integer
---@field acceptedBy string? name of the EMS on the way
---@field acceptedSrc integer?

---@type table<integer, Call>
local calls = {}
local nextId = 0
local lastCall = {}

---@type fun(id: integer?)[] told when a call opens (id) or closes (nil): the EMS app's notification and badge
local listeners = {}

---@param fn fun(id: integer?)
function sos.onChange(fn)
    listeners[#listeners + 1] = fn
end

---@param id integer?
local function changed(id)
    for i = 1, #listeners do listeners[i](id) end
end

local function purge()
    local now = os.time()

    for id, call in pairs(calls) do
        if now - call.at > settings.times.callExpire or not GetPlayerName(call.src) then calls[id] = nil end
    end
end

---Open calls.
---@return integer
function sos.count()
    purge()

    local count = 0
    for _ in pairs(calls) do count = count + 1 end

    return count
end

---@param src integer
---@return Call?
function sos.of(src)
    for _, call in pairs(calls) do
        if call.src == src and call.kind == 'sos' then return call end
    end
end

---@param src integer
---@return string
local function nameOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local info = player and player.PlayerData.charinfo

    return info and ('%s %s'):format(info.firstname, info.lastname) or GetPlayerName(src) or '?'
end

---@param src integer
---@param kind string
---@param text string
---@return Call?
local function create(src, kind, text)
    local now = os.time()

    if lastCall[src] and now - lastCall[src] < settings.times.sosCooldown then return end

    lastCall[src] = now
    nextId = nextId + 1

    local call = { id = nextId, src = src, kind = kind, text = text, coords = GetEntityCoords(GetPlayerPed(src)), at = now }

    calls[call.id] = call

    local _, ems = state.emsOnDuty()

    for i = 1, #ems do
        TriggerClientEvent('city_hospital:client:newCall', ems[i], { id = call.id, text = text, coords = call.coords })
    end

    changed(call.id)

    return call
end

---@param src integer
function sos.closeFor(src)
    local closed = false

    for id, call in pairs(calls) do
        if call.src == src then
            if call.acceptedSrc then TriggerClientEvent('city_hospital:client:callClosed', call.acceptedSrc, id) end
            calls[id] = nil
            closed = true
        end
    end

    if closed then changed(nil) end
end

-- Sending an SOS while down. Finished-off players can't call anyone.
lib.callback.register('city_hospital:sos', function(source)
    local src = source

    if not state.down(src) then return false, 'not_down' end
    if state.isFinalized(src) then return false, 'finalized' end
    if sos.of(src) then return false, 'already_called' end

    local call = create(src, 'sos', locale('call_sos', nameOf(src)))

    if not call then return false, 'cooldown' end

    return true
end)

---@param src integer
---@return boolean
local function ems(src)
    if state.isEms(src) then return true end

    lib.print.warn(('city_hospital: %s asked for EMS calls without being EMS on duty'):format(src))
    return false
end

lib.callback.register('city_hospital:calls', function(source)
    local src = source
    if not ems(src) then return {} end

    purge()

    local list, now = {}, os.time()

    for id, call in pairs(calls) do
        list[#list + 1] = {
            id = id, kind = call.kind, text = call.text, ago = now - call.at, acceptedBy = call.acceptedBy, coords = call.coords,
            mine = call.acceptedSrc == src,
        }
    end

    table.sort(list, function(a, b) return a.id > b.id end)

    return list
end)

-- Accepting a call: the patient sees who is coming, the EMS gets the place for the GPS
lib.callback.register('city_hospital:acceptCall', function(source, id)
    local src = source

    if not ems(src) or type(id) ~= 'number' then return end

    local call = calls[id]
    if not call then return end

    call.acceptedBy = nameOf(src)
    call.acceptedSrc = src
    changed(nil)

    if call.kind == 'sos' then
        exports.qbx_core:Notify(call.src, locale('notify_ems_coming', call.acceptedBy), 'success')
    elseif call.kind == 'phone' then
        -- city_dispatch tells the caller EMS are coming, without the name
        TriggerEvent('city_hospital:server:callAccepted', id)
    end

    return call.coords
end)

-- Closing a call (EMS app): only the EMS who accepted it
lib.callback.register('city_hospital:closeCall', function(source, id)
    local src = source
    local call = ems(src) and math.type(id) == 'integer' and calls[id]

    if not call or call.acceptedSrc ~= src then return false end

    calls[id] = nil
    TriggerClientEvent('city_hospital:client:callClosed', src, id)
    changed(nil)

    return true
end)

-- qbx_radialmenu's emergency button (police and EMS on duty)
RegisterNetEvent('hospital:server:emergencyAlert', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    if not job or not job.onduty or (job.type ~= 'leo' and job.type ~= Config.JobType) then return end

    create(src, 'emergency', locale('call_emergency', nameOf(src)))
end)

-- city_police's panic button ("officer down"): EMS get it too
RegisterNetEvent('hospital:server:ambulanceAlert', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    if not job or job.type ~= 'leo' then return end

    create(src, 'officer', locale('call_officer', nameOf(src)))
end)

-- A 192 call from the phone (city_dispatch builds the text). Returns true and the call id, or false and a reason.
exports('PhoneCall', function(src, text)
    if GetInvokingResource() ~= 'city_dispatch' then return false, 'invalid' end
    if type(src) ~= 'number' or not GetPlayerName(src) or type(text) ~= 'string' then return false, 'invalid' end
    if state.emsOnDuty() == 0 then return false, 'no_units' end

    local call = create(src, 'phone', text:sub(1, 300))
    if not call then return false, 'cooldown' end

    return true, call.id
end)

state.onUp(sos.closeFor)

AddEventHandler('city_hospital:server:finalized', function(src)
    sos.closeFor(src)
end)

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
end)

return sos
