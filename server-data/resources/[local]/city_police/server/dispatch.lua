-- Police calls: 190 calls (city_dispatch forwards them), alerts from scripts and the officer panic button. Kept in
-- memory for Config.Dispatch.minutes. Officers on duty get a tablet notification, a blip and a sound; units attach to
-- a call from the MDT, which sets their GPS and their status.

local police = require 'server.police'
local roster = require 'server.roster'
local settings = require 'server.config'

local dispatch = {}

---@class PoliceCall
---@field id integer
---@field kind string 'phone' | 'alert' | 'panic' | 'radar'
---@field code string
---@field title string
---@field text string
---@field caller string?
---@field coords vector3
---@field at integer
---@field priority integer 1 normal, 2 high
---@field units table<integer, true>
---@field notes { name: string, text: string, at: integer }[]
---@field src integer? phone caller
---@field accepted boolean the caller already heard someone is coming

---@type table<integer, PoliceCall>
local calls = {}
local nextId = 0
local LIFETIME = Config.Dispatch.minutes * 60

local function purge()
    local now = os.time()

    for id, call in pairs(calls) do
        if now - call.at > LIFETIME then
            calls[id] = nil
            police.toOnDuty('city_police:client:callClosed', id)
        end
    end
end

---@return integer
local function openCount()
    local count = 0
    for _ in pairs(calls) do count = count + 1 end
    return count
end

local function updateBadges()
    local count = openCount()

    for _, src in ipairs(police.onDutyList()) do
        exports.city_os:SetBadge(src, Config.App.id, count)
    end
end

---A call as the MDT shows it.
---@param call PoliceCall
---@param viewer integer
---@return table
function dispatch.view(call, viewer)
    local units = {}

    for src in pairs(call.units) do
        local unit = roster.unit(src)
        if unit then units[#units + 1] = { name = unit.name, callsign = unit.callsign } end
    end

    return {
        id = call.id,
        kind = call.kind,
        code = call.code,
        title = call.title,
        text = call.text,
        caller = call.caller,
        coords = { x = call.coords.x, y = call.coords.y, z = call.coords.z },
        at = call.at,
        priority = call.priority,
        units = units,
        notes = call.notes,
        attached = call.units[viewer] == true,
    }
end

---Opens a call and tells every officer on duty.
---@param data { kind: string, code: string?, title: string, text: string?, caller: string?, coords: vector3, priority: integer?, src: integer? }
---@return integer? id
function dispatch.add(data)
    purge()

    local officers = police.onDutyList()
    if #officers == 0 then return end

    nextId = nextId + 1

    local call = {
        id = nextId,
        kind = data.kind,
        code = data.code or '10-00',
        title = police.clean(data.title, settings.text.short),
        text = police.clean(data.text, settings.text.line),
        caller = data.caller,
        coords = vec3(data.coords.x, data.coords.y, data.coords.z),
        at = os.time(),
        priority = data.priority == 2 and 2 or 1,
        units = {},
        notes = {},
        src = data.src,
        accepted = false,
    }

    calls[call.id] = call

    for _, src in ipairs(officers) do
        TriggerClientEvent('city_police:client:newCall', src, { id = call.id, kind = call.kind, code = call.code, title = call.title, coords = call.coords, priority = call.priority })

        exports.city_os:Notify(src, {
            app = Config.App.id,
            title = ('%s · %s'):format(call.code, call.title),
            body = call.text ~= '' and call.text or locale('call_no_text'),
            banner = true,
            open = { tab = 'dispatch', call = call.id },
        })
    end

    updateBadges()
    TriggerEvent('city_police:server:callsChanged')

    return call.id
end

---@return PoliceCall[]
function dispatch.list()
    purge()

    local list = {}
    for _, call in pairs(calls) do list[#list + 1] = call end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.id > b.id
    end)

    return list
end

---@param id unknown
---@return PoliceCall?
function dispatch.get(id)
    purge()

    return math.type(id) == 'integer' and calls[id] or nil
end

---@param src integer
---@param call PoliceCall
function dispatch.attach(src, call)
    -- One call at a time: leaving the old one first
    local unit = roster.unit(src)
    if unit and unit.call and calls[unit.call] then calls[unit.call].units[src] = nil end

    call.units[src] = true
    roster.setCall(src, call.id)

    if call.src and not call.accepted then
        call.accepted = true
        TriggerEvent('city_police:server:callAccepted', call.src)
    end

    TriggerEvent('city_police:server:callsChanged')
end

---@param src integer
---@param call PoliceCall
function dispatch.detach(src, call)
    call.units[src] = nil
    roster.setCall(src, nil)
    TriggerEvent('city_police:server:callsChanged')
end

---@param src integer
---@param call PoliceCall
---@param text string
function dispatch.note(src, call, text)
    call.notes[#call.notes + 1] = { name = police.name(src), text = text, at = os.time() }
    if #call.notes > 20 then table.remove(call.notes, 1) end

    TriggerEvent('city_police:server:callsChanged')
end

---@param call PoliceCall
function dispatch.close(call)
    calls[call.id] = nil

    for src in pairs(call.units) do roster.setCall(src, nil) end

    police.toOnDuty('city_police:client:callClosed', call.id)
    updateBadges()
    TriggerEvent('city_police:server:callsChanged')
end

---@return integer
function dispatch.count()
    purge()

    return openCount()
end

-- A unit going off duty leaves its call
AddEventHandler('city_police:server:offDuty', function(src)
    for _, call in pairs(calls) do call.units[src] = nil end
    exports.city_os:SetBadge(src, Config.App.id, 0)
end)

-- Alerts from other server scripts: exports.city_police:Alert({ title, text, coords, code, priority })
exports('Alert', function(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' then return false end

    local coords = data.coords
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' and type(coords) ~= 'table' then return false end
    if not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then return false end

    return dispatch.add({
        kind = 'alert',
        code = type(data.code) == 'string' and data.code:sub(1, 8) or '10-90',
        title = data.title,
        text = type(data.text) == 'string' and data.text or '',
        coords = vec3(coords.x, coords.y, coords.z),
        priority = data.priority,
    }) ~= nil
end)

-- 190 calls from the phone (city_dispatch). Returns false, 'no_units' when nobody is on duty.
exports('PhoneCall', function(src, kind, text, caller)
    if type(src) ~= 'number' or not GetPlayerName(src) then return false, 'invalid' end
    if #police.onDutyList() == 0 then return false, 'no_units' end

    local id = dispatch.add({
        kind = 'phone',
        code = '190',
        title = type(kind) == 'string' and kind or locale('call_phone'),
        text = type(text) == 'string' and text or '',
        caller = type(caller) == 'string' and caller or nil,
        coords = GetEntityCoords(GetPlayerPed(src)),
        src = src,
    })

    if not id then return false, 'no_units' end

    return true, id
end)

return dispatch
