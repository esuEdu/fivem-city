-- What an officer on duty does to the player or the vehicle in front of them: ALT (ox_target) shows one "Police
-- actions" item that opens the round menu (client/radial.lua), and qbx_radialmenu's police buttons. The server
-- checks each action again.

local job = require 'client.job'
local radial = require 'client.radial'

local REACH = Config.Ranges.player

---@param target integer server id
---@param soft boolean
local function cuff(target, soft)
    local ok, result = lib.callback.await('city_police:cuff', false, target, soft)
    if not ok then return job.fail(result) end

    -- The officer's side of the paired animation
    lib.requestAnimDict('mp_arrest_paired')
    TaskPlayAnim(cache.ped, 'mp_arrest_paired', 'cop_p2_back_right', 3.0, 3.0, -1, 48, 0, false, false, false)
    RemoveAnimDict('mp_arrest_paired')

    exports.qbx_core:Notify(locale(result and 'cuffed_them' or 'uncuffed_them'), 'success')
end

---@param target integer
local function escort(target)
    local ok, result = lib.callback.await('city_police:escort', false, target)
    if not ok then return job.fail(result) end
end

-- Seat names by index (-1 driver); vans and buses go on with "Seat n"
local SEATS = { [-1] = 'seat_driver', [0] = 'seat_front', [1] = 'seat_rear_left', [2] = 'seat_rear_right' }

---@param seat integer
---@return string
local function seatLabel(seat)
    return SEATS[seat] and locale(SEATS[seat]) or locale('seat_other', seat + 2)
end

---Asks which seat: the free passenger seats (putting in) or the taken ones (taking out).
---@param vehicle integer
---@param taken boolean
---@return integer? seat
local function chooseSeat(vehicle, taken)
    local items = {}

    for seat = taken and -1 or 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        local free = ped == 0
        local usable = taken and (not free and IsPedAPlayer(ped) and ped ~= cache.ped) or (not taken and free)

        items[#items + 1] = { id = tostring(seat), label = seatLabel(seat), icon = 'seat', disabled = not usable, hint = tostring(seat + 2) }
    end

    local picked = radial.choose({ title = locale(taken and 'radial_take_out' or 'radial_put_in'), subtitle = locale('radial_pick_seat'), items = items })

    return picked and math.tointeger(tonumber(picked)) or nil
end

---@param target integer
local function putInVehicle(target)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.Ranges.vehicle, false)
    if not vehicle then return job.fail('no_vehicle') end

    local seat = chooseSeat(vehicle, false)
    if not seat then return end

    local ok, reason = lib.callback.await('city_police:putInVehicle', false, target, NetworkGetNetworkIdFromEntity(vehicle), seat)
    if not ok then job.fail(reason) end
end

---@param vehicle integer
local function takeOut(vehicle)
    local seat = chooseSeat(vehicle, true)
    if not seat then return end

    local ped = GetPedInVehicleSeat(vehicle, seat)
    if ped == 0 or not IsPedAPlayer(ped) then return job.fail('no_one_near') end

    local ok, reason = lib.callback.await('city_police:takeOutOfVehicle', false, job.serverIdOf(ped))
    if not ok then job.fail(reason) end
end

---@param target integer
local function checkStatus(target)
    local ok, list = lib.callback.await('city_police:checkStatus', false, target)
    if not ok then return job.fail(list) end

    if #list == 0 then return exports.qbx_core:Notify(locale('status_none'), 'inform') end

    for _, id in ipairs(list) do
        exports.qbx_core:Notify(locale(('status_%s'):format(id)), 'inform')
    end
end

---@param target integer
local function anklet(target)
    if not Config.Features.anklet then return job.fail('feature_off') end

    local ok, result = lib.callback.await('city_police:anklet', false, target)
    if not ok then return job.fail(result) end

    exports.qbx_core:Notify(locale(result and 'anklet_on' or 'anklet_off'), 'success')
end

---Restrained suspects open straight away; anyone else is asked first and the server opens it if they accept.
---@param target integer
local function search(target)
    local ok, result = lib.callback.await('city_police:search', false, target)
    if not ok then return job.fail(result) end

    if result == 'open' then return exports.city_inventory:openInventory('player', target) end

    exports.qbx_core:Notify(locale('search_asked'), 'inform')
end

---Opens the tablet on the MDT, showing what args ask (a person by server id, a plate, a new case).
---@param args table
local function openMdt(args)
    if not exports.city_os:OpenApp(Config.App.id, args) then job.fail('no_tablet') end
end

-- Impounding the empty car in front: reason, fee and hold time, then a short progress
local function impound(vehicle)
    local input = lib.inputDialog(locale('impound_title'), {
        { type = 'input', label = locale('impound_reason'), required = true, max = 160 },
        { type = 'number', label = locale('impound_fee'), default = 500, min = 0, max = 10000 },
        { type = 'number', label = locale('impound_hours'), default = 0, min = 0, max = 72 },
    })
    if not input then return end

    if lib.progressCircle({ duration = 5000, label = locale('impounding'), position = 'bottom', disable = { move = true, car = true, combat = true } }) then
        local ok, result = lib.callback.await('city_police:mdt:impound', false, {
            netId = NetworkGetNetworkIdFromEntity(vehicle), reason = input[1], fee = math.floor(input[2] or 0), hours = math.floor(input[3] or 0),
        })

        if not ok then return job.fail(result) end
        exports.qbx_core:Notify(locale(result.owned and 'impounded' or 'impounded_local', result.plate), 'success')
    end
end

---@param target integer server id
local function playerMenu(target)
    local picked = radial.choose({
        title = locale('radial_title'),
        subtitle = locale('radial_player'),
        items = {
            { id = 'mdt', label = locale('radial_open_file'), icon = 'tablet' },
            { id = 'cuff', label = locale('target_cuff'), icon = 'cuff' },
            { id = 'softcuff', label = locale('target_softcuff'), icon = 'link' },
            { id = 'escort', label = locale('target_escort'), icon = 'escort' },
            { id = 'putin', label = locale('target_put_in'), icon = 'car' },
            { id = 'search', label = locale('target_search'), icon = 'search' },
            { id = 'fine', label = locale('radial_fine'), icon = 'bill' },
            { id = 'status', label = locale('target_status'), icon = 'eye' },
            Config.Features.anklet and { id = 'anklet', label = locale('target_anklet'), icon = 'anklet' } or nil,
        },
    })

    if picked == 'mdt' then openMdt({ tab = 'people', serverId = target })
    elseif picked == 'cuff' then cuff(target, false)
    elseif picked == 'softcuff' then cuff(target, true)
    elseif picked == 'escort' then escort(target)
    elseif picked == 'putin' then putInVehicle(target)
    elseif picked == 'search' then search(target)
    elseif picked == 'fine' then openMdt({ tab = 'reports', serverId = target })
    elseif picked == 'status' then checkStatus(target)
    elseif picked == 'anklet' then anklet(target) end
end

---@param vehicle integer
local function hasPlayerInside(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) and ped ~= cache.ped then return true end
    end

    return false
end

---@param vehicle integer
local function vehicleMenu(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle):match('^%s*(.-)%s*$')
    local empty = GetVehicleNumberOfPassengers(vehicle) == 0 and IsVehicleSeatFree(vehicle, -1)

    local picked = radial.choose({
        title = locale('radial_title'),
        subtitle = plate,
        items = {
            { id = 'mdt', label = locale('radial_open_vehicle'), icon = 'tablet' },
            { id = 'takeout', label = locale('target_take_out'), icon = 'exit', disabled = not hasPlayerInside(vehicle) },
            { id = 'impound', label = locale('target_impound'), icon = 'tow', disabled = not empty },
        },
    })

    if picked == 'mdt' then openMdt({ tab = 'vehicles', plate = plate })
    elseif picked == 'takeout' then takeOut(vehicle)
    elseif picked == 'impound' then impound(vehicle) end
end

RegisterNetEvent('city_police:client:openSearch', function(target)
    if type(target) ~= 'number' then return end

    exports.city_inventory:openInventory('player', target)
end)

-- An officer asks to search us: accept or refuse before the time runs out
RegisterNetEvent('city_police:client:searchRequest', function(officer, seconds)
    local answered = false

    SetTimeout(seconds * 1000, function()
        if not answered then lib.closeAlertDialog() end
    end)

    local choice = lib.alertDialog({
        header = locale('search_request_header'),
        content = locale('search_request_text', officer, seconds),
        centered = true,
        cancel = true,
        labels = { confirm = locale('search_accept'), cancel = locale('search_refuse') },
    })

    answered = true
    TriggerServerEvent('city_police:server:searchAnswer', choice == 'confirm')
end)

exports.ox_target:addGlobalPlayer({
    {
        name = 'city_police:actions', label = locale('radial_title'), icon = 'fas fa-shield-halved', distance = REACH,
        canInteract = job.onDuty,
        onSelect = function(data) playerMenu(job.serverIdOf(data.entity)) end,
    },
})

exports.ox_target:addGlobalVehicle({
    {
        name = 'city_police:vehicleActions', label = locale('radial_title'), icon = 'fas fa-shield-halved', distance = Config.Ranges.vehicle,
        canInteract = function(entity) return job.onDuty() and entity ~= cache.vehicle end,
        onSelect = function(data) vehicleMenu(data.entity) end,
    },
})

-- The radial menu's police buttons (qbx_radialmenu's config fires these on the client)
local function onClosest(fn, distance)
    return function()
        if not job.onDuty() then return end

        local target = job.closestPlayer(distance or REACH)
        if not target then return exports.qbx_core:Notify(locale('error_no_one_near'), 'error') end

        fn(target)
    end
end

AddEventHandler('city_police:client:radialCuff', onClosest(function(t) cuff(t, false) end, Config.Ranges.cuff))
AddEventHandler('city_police:client:radialSoftCuff', onClosest(function(t) cuff(t, true) end, Config.Ranges.cuff))
AddEventHandler('city_police:client:radialEscort', onClosest(escort))
AddEventHandler('city_police:client:radialPutIn', onClosest(putInVehicle))
AddEventHandler('city_police:client:radialTakeOut', function()
    if not job.onDuty() then return end

    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.Ranges.vehicle, false)
    if not vehicle then return job.fail('no_vehicle') end

    takeOut(vehicle)
end)
AddEventHandler('city_police:client:radialSearch', onClosest(search))
AddEventHandler('city_police:client:radialStatus', onClosest(checkStatus))
AddEventHandler('city_police:client:radialAnklet', onClosest(anklet))

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalPlayer({ 'city_police:actions' })
    exports.ox_target:removeGlobalVehicle({ 'city_police:vehicleActions' })
end)
