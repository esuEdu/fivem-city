-- The Staff app page talks to this file (NUI callbacks); every request goes to a server callback that checks the
-- staff member's level and duty again.

local selfTools = require 'client.self'
local spectate = require 'client.spectate'

-- Server callbacks the page may call (city_staff:<name>)
local ACTIONS = {
    app = true, dashboard = true, ratings = true, players = true, player = true, log = true,
    ['goto'] = true, bring = true, heal = true, revive = true, freeze = true, kill = true, cuff = true,
    clothing = true, bucket = true, setJob = true, setGang = true, inventory = true, spectate = true,
    warn = true, kick = true, ban = true, bans = true, unban = true,
    reports = true, claimReport = true, replyReport = true, closeReport = true,
    noclip = true, invisible = true, godmode = true, names = true, blips = true,
    spawnVehicle = true, fixVehicle = true, deleteVehicle = true, saveVehicle = true,
}

-- Tools that close the tablet first, because the player needs the game view (or the inventory) to use them
local CLOSES_TABLET = { inventory = true, spectate = true, noclip = true }

---Fills in what only this client knows (its vehicle), or returns why the action can't run.
---@param action string
---@param args table
---@return string? reason
local function prepare(action, args)
    if action == 'fixVehicle' or action == 'saveVehicle' then
        if not cache.vehicle then return 'no_vehicle' end
        if action == 'saveVehicle' then args.props = lib.getVehicleProperties(cache.vehicle) end
    elseif action == 'deleteVehicle' then
        local vehicle = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.DeleteVehicleDistance, true)
        if not vehicle then return 'no_vehicle' end
        args.netId = NetworkGetNetworkIdFromEntity(vehicle)
    elseif selfTools.all()[action] ~= nil then
        args.on = not selfTools.get(action)
    end
end

---"Zone, Street" for a position; street names only exist on the client.
---@param coords vector3
---@return string
local function placeName(coords)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    return zone ~= 'NULL' and ('%s, %s'):format(zone, street) or street
end

---What happens on this client after the server said yes.
---@param action string
---@param result any
local function finish(action, result)
    if CLOSES_TABLET[action] and exports.city_os:IsOpen() then exports.city_os:Close() end

    if action == 'player' then
        result.place = placeName(result.coords)
        result.coords = nil
    elseif action == 'inventory' then
        exports.ox_inventory:openInventory('player', result)
    elseif action == 'spectate' then
        spectate.start(result)
    elseif selfTools.all()[action] ~= nil then
        selfTools.set(action, result == true)
    elseif action == 'fixVehicle' and cache.vehicle then
        SetVehicleFixed(cache.vehicle)
        SetVehicleEngineHealth(cache.vehicle, 1000.0)
        SetVehicleDirtLevel(cache.vehicle, 0.0)
    end
end

---Runs one staff action: checks on this client, the server callback, then what this client does after.
---@param action string
---@param args table
---@return { ok: boolean, data: any?, reason: string? }
local function run(action, args)
    local reason = prepare(action, args)
    if reason then return { ok = false, reason = reason } end

    local ok, result = lib.callback.await(('city_staff:%s'):format(action), false, args)
    if not ok then return { ok = false, reason = result or 'failed' } end

    finish(action, result)

    return { ok = true, data = result }
end

RegisterNUICallback('run', function(data, cb)
    local action = type(data) == 'table' and data.action

    if not ACTIONS[action] then return cb({ ok = false, reason = 'invalid' }) end

    local response = run(action, type(data.args) == 'table' and data.args or {})

    if action == 'app' and response.ok then
        response.data.labels = lib.getLocales()
        response.data.tools = selfTools.all()
    end

    cb(response)
end)

RegisterNetEvent('city_staff:client:reportsChanged', function()
    if GetInvokingResource() then return end

    exports.city_os:SendAppMessage(Config.App.id, { type = 'reports' })
end)
