-- The MDT page talks to this file (NUI callbacks). Each action goes to the server callback city_police:mdt:<action>,
-- which checks duty and grade again; a few need this client first (a photo, the car in front) or after (GPS, camera).

local job = require 'client.job'
local cameras = require 'client.cameras'

local ACTIONS = {
    app = true, dashboard = true, calls = true, callAttach = true, callDetach = true, callNote = true, callClose = true,
    callGps = true, units = true, setStatus = true, setCallsign = true, map = true,
    searchPeople = true, person = true, searchVehicles = true, vehicle = true, flagPlate = true, clearPlate = true,
    searchWeapons = true, weapon = true, setWeaponStatus = true,
    reports = true, report = true, saveReport = true,
    warrants = true, issueWarrant = true, closeWarrant = true,
    charge = true, nearby = true,
    impounds = true, impound = true, release = true,
    licences = true, setLicence = true,
    evidence = true, analyze = true, evidenceItem = true, scanFingerprint = true, viewCamera = true,
    members = true, setCert = true, setGrade = true, fire = true, hire = true, nearbyCivilians = true,
    notices = true, addNotice = true, deleteNotice = true,
}

-- Tools that need the game view
local CLOSES_TABLET = { viewCamera = true }

---@param coords table
local function waypoint(coords)
    if coords and coords.x then SetNewWaypoint(coords.x + 0.0, coords.y + 0.0) end
end

---Fills in what only this client knows, or returns why the action can't run.
---@param action string
---@param args table
---@return string? reason
local function prepare(action, args)
    if action == 'charge' and args.kind == 'arrest' then
        local player = GetPlayerFromServerId(math.tointeger(args.target) or -1)
        if player == -1 then return 'too_far' end

        args.photo = exports.MugShotBase64:GetMugShotBase64(GetPlayerPed(player), false)
    elseif action == 'impound' then
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.Ranges.vehicle, false)
        if not vehicle then return 'no_vehicle' end

        args.netId = NetworkGetNetworkIdFromEntity(vehicle)
    end
end

---@param list table[]
local function addPlaces(list)
    for _, call in ipairs(list or {}) do
        if call.coords then call.place = job.place(call.coords) end
    end
end

---What happens on this client after the server said yes.
---@param action string
---@param result any
local function finish(action, result)
    if CLOSES_TABLET[action] and exports.city_os:IsOpen() then exports.city_os:Close() end

    if action == 'callAttach' or action == 'callGps' then
        waypoint(result)
    elseif action == 'viewCamera' then
        Wait(300)
        cameras.open(result)
    elseif action == 'calls' then
        addPlaces(result)
    elseif action == 'dashboard' then
        addPlaces(result.calls)
    end
end

---@param action string
---@param args table
---@return table
local function run(action, args)
    local reason = prepare(action, args)
    if reason then return { ok = false, reason = reason } end

    local ok, result = lib.callback.await(('city_police:mdt:%s'):format(action), false, args)
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
        response.data.cameraStates = cameras.states()
    end

    cb(response)
end)

-- Things the page does on this client only
RegisterNUICallback('waypoint', function(data, cb)
    cb(1)
    waypoint(type(data) == 'table' and data or nil)
end)

RegisterNUICallback('cameraStates', function(_, cb)
    cb(cameras.states())
end)

RegisterNUICallback('openMap', function(_, cb)
    cb(1)
    if exports.city_os:IsOpen() then exports.city_os:Close() end

    Wait(300)
    ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1)
end)

RegisterNetEvent('city_police:client:mdtRefresh', function(what)
    if GetInvokingResource() then return end

    exports.city_os:SendAppMessage(Config.App.id, { type = 'refresh', what = what })
end)
