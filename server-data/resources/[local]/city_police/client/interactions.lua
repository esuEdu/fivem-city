-- What an officer on duty does to the player in front of them (ox_target and the radial menu), and impounding the
-- vehicle in front of them. The server checks each action again.

local job = require 'client.job'

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

---The closest vehicle with a free seat, as a net id.
---@return integer?
local function closestVehicle()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.Ranges.vehicle, false)

    return vehicle and NetworkGetNetworkIdFromEntity(vehicle) or nil
end

---@param target integer
local function putInVehicle(target)
    local netId = closestVehicle()
    if not netId then return job.fail('no_vehicle') end

    local ok, reason = lib.callback.await('city_police:putInVehicle', false, target, netId)
    if not ok then job.fail(reason) end
end

---@param target integer
local function takeOut(target)
    local ok, reason = lib.callback.await('city_police:takeOutOfVehicle', false, target)
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

local OPTIONS = {
    { name = 'city_police:cuff', label = locale('target_cuff'), icon = 'fas fa-handcuffs', distance = Config.Ranges.cuff, fn = function(t) cuff(t, false) end },
    { name = 'city_police:softcuff', label = locale('target_softcuff'), icon = 'fas fa-link', distance = Config.Ranges.cuff, fn = function(t) cuff(t, true) end },
    { name = 'city_police:escort', label = locale('target_escort'), icon = 'fas fa-people-pulling', fn = escort },
    { name = 'city_police:putin', label = locale('target_put_in'), icon = 'fas fa-car-side', fn = putInVehicle },
    { name = 'city_police:search', label = locale('target_search'), icon = 'fas fa-magnifying-glass', fn = search },
    { name = 'city_police:status', label = locale('target_status'), icon = 'fas fa-eye', fn = checkStatus },
    Config.Features.anklet and { name = 'city_police:anklet', label = locale('target_anklet'), icon = 'fas fa-satellite-dish', fn = anklet } or nil,
}

local targetOptions = {}
for i, option in ipairs(OPTIONS) do
    targetOptions[i] = {
        name = option.name, label = option.label, icon = option.icon, distance = option.distance or REACH,
        canInteract = job.onDuty,
        onSelect = function(data) option.fn(job.serverIdOf(data.entity)) end,
    }
end

exports.ox_target:addGlobalPlayer(targetOptions)

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

local VEHICLE_OPTIONS = {
    {
        name = 'city_police:takeout', label = locale('target_take_out'), icon = 'fas fa-person-walking-arrow-right', distance = Config.Ranges.vehicle,
        canInteract = function(entity)
            if not job.onDuty() then return false end
            for seat = -1, GetVehicleMaxNumberOfPassengers(entity) - 1 do
                local ped = GetPedInVehicleSeat(entity, seat)
                if ped ~= 0 and IsPedAPlayer(ped) and ped ~= cache.ped then return true end
            end
            return false
        end,
        onSelect = function(data)
            for seat = -1, GetVehicleMaxNumberOfPassengers(data.entity) - 1 do
                local ped = GetPedInVehicleSeat(data.entity, seat)
                if ped ~= 0 and IsPedAPlayer(ped) and ped ~= cache.ped then takeOut(job.serverIdOf(ped)) end
            end
        end,
    },
    {
        name = 'city_police:impound', label = locale('target_impound'), icon = 'fas fa-truck-pickup', distance = Config.Ranges.vehicle,
        canInteract = function(entity) return job.onDuty() and GetVehicleNumberOfPassengers(entity) == 0 and IsVehicleSeatFree(entity, -1) end,
        onSelect = function(data) impound(data.entity) end,
    },
}

exports.ox_target:addGlobalVehicle(VEHICLE_OPTIONS)

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

    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) and ped ~= cache.ped then takeOut(job.serverIdOf(ped)) end
    end
end)
AddEventHandler('city_police:client:radialSearch', onClosest(search))
AddEventHandler('city_police:client:radialStatus', onClosest(checkStatus))
AddEventHandler('city_police:client:radialAnklet', onClosest(anklet))

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    local names = {}
    for i, option in ipairs(targetOptions) do names[i] = option.name end
    exports.ox_target:removeGlobalPlayer(names)

    names = {}
    for i, option in ipairs(VEHICLE_OPTIONS) do names[i] = option.name end
    exports.ox_target:removeGlobalVehicle(names)
end)
