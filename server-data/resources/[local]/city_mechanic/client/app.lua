-- The Mechanic tablet app (web/app/) talks to this file. Every request goes to a server callback that checks the job
-- again: ours (city_mechanic:app:<name>) or, for the 555 calls, city_dispatch's own.

-- Server callbacks the page may call (city_mechanic:app:<name>)
local ACTIONS = {
    app = true, dashboard = true, services = true, team = true, candidates = true, hire = true, setGrade = true, fire = true,
}

---"Zone, Street" for a position; street names only exist on the client.
---@param coords vector3 | { x: number, y: number, z: number }
---@return string
local function placeName(coords)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    return zone ~= 'NULL' and ('%s, %s'):format(zone, street) or street
end

---@param id unknown
---@return integer?
local function callId(id)
    return math.type(id) == 'integer' and id or nil
end

---The calls actions, answered by city_dispatch (which checks the job and duty).
local CALLS = {
    calls = function()
        local list = lib.callback.await('city_dispatch:calls', false)
        if not list then return { ok = false, reason = 'not_on_duty' } end

        for _, call in ipairs(list) do
            call.place = placeName(call.coords)
            call.coords = nil
        end

        return { ok = true, data = list }
    end,

    respond = function(args)
        local id = callId(args.id)
        local coords = id and lib.callback.await('city_dispatch:respond', false, id)
        if not coords then return { ok = false, reason = 'call_gone' } end

        SetNewWaypoint(coords.x, coords.y)

        return { ok = true }
    end,

    close = function(args)
        local id = callId(args.id)
        if not id or not lib.callback.await('city_dispatch:close', false, id) then return { ok = false, reason = 'call_gone' } end

        return { ok = true }
    end,
}

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action
    local args = type(data) == 'table' and type(data.args) == 'table' and data.args or {}

    if CALLS[action] then return cb(CALLS[action](args)) end
    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local ok, result = lib.callback.await(('city_mechanic:app:%s'):format(action), false, args)
    if not ok then return cb({ ok = false, reason = result or 'failed' }) end

    if action == 'app' then result.labels = lib.getLocales() end

    cb({ ok = true, data = result })
end)

RegisterNetEvent('city_mechanic:client:appMessage', function(message)
    if GetInvokingResource() or type(message) ~= 'table' then return end

    exports.city_os:SendAppMessage(Config.App.id, message)
end)
