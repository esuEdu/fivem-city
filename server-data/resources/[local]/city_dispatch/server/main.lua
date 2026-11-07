-- Calls to the city services. The phone (city_phone_calls) reports a call with the Report export; responders on duty
-- get it at once, see the open ones with /calls and respond (GPS). The caller only hears that someone is on the way,
-- never who. 192 calls go to city_hospital's calls list instead.
lib.locale()

---@class DispatchCall
---@field id integer
---@field service string
---@field src integer caller
---@field kind string
---@field text string
---@field caller string? name and number, nil when anonymous
---@field coords vector3
---@field at integer
---@field responders table<integer, true>
---@field notified boolean the caller already heard someone is coming

---@type table<integer, DispatchCall>
local calls = {}
local nextId = 0
---@type table<integer, table<string, integer>> src -> service -> os.time() of the last call
local lastCall = {}
---@type table<integer, { src: integer, at: integer, notified: boolean }> city_hospital call id -> our caller
local hospitalCalls = {}

local EXPIRE = Config.ExpireMinutes * 60

---@param text unknown
---@return string
local function clean(text)
    if type(text) ~= 'string' then return '' end

    return text:gsub('[%c<>]', ' '):match('^%s*(.-)%s*$'):sub(1, Config.TextLength)
end

---@param list string[]
---@param value unknown
---@return boolean
local function has(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end

    return false
end

---@param call DispatchCall
---@param now integer
---@return boolean
local function expired(call, now)
    return now - call.at > EXPIRE
end

---The service a player answers calls for (on duty), if any. EMS use city_hospital's list.
---@param src integer
---@return string?
local function serviceOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or not job.onduty then return end

    for id, service in pairs(Config.Services) do
        if not service.hospital and service.jobType == job.type then return id end
    end
end

---@param src integer
---@param service string
---@return boolean
local function coolingDown(src, service)
    local last = lastCall[src] and lastCall[src][service]

    return last ~= nil and os.time() - last < Config.CooldownSeconds
end

---@param call DispatchCall
---@param viewer integer
---@param now integer
local function view(call, viewer, now)
    local count = 0
    for _ in pairs(call.responders) do count = count + 1 end

    return {
        id = call.id,
        service = call.service,
        kind = Config.TypeLabels[call.kind] or call.kind,
        text = call.text,
        caller = call.caller or locale('anonymous'),
        coords = call.coords,
        ago = now - call.at,
        responders = count,
        responding = call.responders[viewer] == true,
    }
end

---@param call DispatchCall
---@param event string
---@param ... any
local function toResponders(call, event, ...)
    local _, list = exports.qbx_core:GetDutyCountType(Config.Services[call.service].jobType)

    for i = 1, #(list or {}) do
        TriggerClientEvent(event, list[i], ...)
    end
end

---@param src integer
---@param service string
local function tellCaller(src, service)
    if not GetPlayerName(src) then return end

    exports.city_phone:Notify(src, { app = 'phone', title = Config.Services[service].number, text = locale(('on_the_way_%s'):format(service)) })
end

local function purge()
    local now = os.time()

    for id, call in pairs(calls) do
        if expired(call, now) then calls[id] = nil end
    end

    for id, entry in pairs(hospitalCalls) do
        if now - entry.at > EXPIRE then hospitalCalls[id] = nil end
    end
end

-- The fixed contacts every phone shows
exports('Services', function()
    local list = {}

    for _, id in ipairs(Config.Order) do
        local service = Config.Services[id]
        list[#list + 1] = { id = id, number = service.number, types = service.types }
    end

    return list
end)

---A call from a player's phone. Returns false and a reason ('invalid', 'cooldown', 'no_units') when it isn't sent.
---@param src integer
---@param serviceId string
---@param kind string one of the service's types
---@param text string
---@param anonymous boolean
---@return boolean, string?
exports('Report', function(src, serviceId, kind, text, anonymous)
    local player = type(src) == 'number' and exports.qbx_core:GetPlayer(src)
    local service = type(serviceId) == 'string' and Config.Services[serviceId]

    if not player or not service or not has(service.types, kind) then return false, 'invalid' end
    if coolingDown(src, serviceId) then return false, 'cooldown' end

    purge()

    local info = player.PlayerData.charinfo
    local caller = not anonymous and locale('caller', ('%s %s'):format(info.firstname, info.lastname), tostring(info.phone or '')) or nil
    local message = clean(text)

    if service.hospital then
        local body = message ~= '' and message or '-'
        local ok, id = exports.city_hospital:PhoneCall(src, locale('ems_call', Config.TypeLabels[kind], caller or locale('anonymous'), body))
        if not ok then return false, id end

        hospitalCalls[id] = { src = src, at = os.time(), notified = false }
    else
        local count, list = exports.qbx_core:GetDutyCountType(service.jobType)
        if not count or count == 0 then return false, 'no_units' end

        nextId = nextId + 1

        local call = {
            id = nextId,
            service = serviceId,
            src = src,
            kind = kind,
            text = message,
            caller = caller,
            coords = GetEntityCoords(GetPlayerPed(src)),
            at = os.time(),
            responders = {},
            notified = false,
        }

        calls[call.id] = call

        for i = 1, #list do
            TriggerClientEvent('city_dispatch:client:newCall', list[i], view(call, list[i], call.at))
        end
    end

    lastCall[src] = lastCall[src] or {}
    lastCall[src][serviceId] = os.time()

    return true
end)

-- city_hospital: an EMS accepted a call; if it came from the phone, the caller hears EMS are coming (only once)
AddEventHandler('city_hospital:server:callAccepted', function(id)
    if GetInvokingResource() ~= 'city_hospital' then return end

    local entry = hospitalCalls[id]
    if not entry or entry.notified then return end

    entry.notified = true
    tellCaller(entry.src, 'ems')
end)

lib.callback.register('city_dispatch:calls', function(source)
    local src = source
    local service = serviceOf(src)
    if not service then return false end

    purge()

    local list, now = {}, os.time()

    for _, call in pairs(calls) do
        if call.service == service then list[#list + 1] = view(call, src, now) end
    end

    table.sort(list, function(a, b) return a.id > b.id end)

    return list
end)

---@param src integer
---@param id unknown
---@return DispatchCall?
local function callFor(src, id)
    local service = serviceOf(src)
    local call = math.type(id) == 'integer' and calls[id]

    if not service or not call or call.service ~= service or expired(call, os.time()) then
        lib.print.warn(('city_dispatch: %s asked for call %s without being able to answer it'):format(src, tostring(id)))
        return
    end

    return call
end

lib.callback.register('city_dispatch:respond', function(source, id)
    local src = source
    local call = callFor(src, id)
    if not call then return end

    call.responders[src] = true

    if not call.notified then
        call.notified = true
        tellCaller(call.src, call.service)
    end

    return call.coords
end)

-- Only someone responding to the call can close it; every responder loses its blip
lib.callback.register('city_dispatch:close', function(source, id)
    local src = source
    local call = callFor(src, id)
    if not call or not call.responders[src] then return false end

    calls[call.id] = nil
    toResponders(call, 'city_dispatch:client:closed', call.id)

    return true
end)

AddEventHandler('playerDropped', function()
    local src = source

    lastCall[src] = nil

    for _, call in pairs(calls) do
        call.responders[src] = nil
    end
end)
