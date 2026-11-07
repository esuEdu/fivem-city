-- EMS places: duty, armory, lockers, garages, the Pillbox elevator and the calls list. Every option is shown only to
-- the EMS job; the server checks again.
local PLACE_RADIUS = 1.5
local CALL_BLIP_MS = 120000

local zones = {}
local callBlips = {}

local function job()
    return QBX.PlayerData and QBX.PlayerData.job
end

local function isEms()
    local current = job()
    return current ~= nil and current.name == Config.Job
end

local function onDuty()
    local current = job()
    return isEms() and current.onduty == true
end

local function zone(coords, options)
    zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = coords, radius = PLACE_RADIUS, options = options })
end

local function toggleDuty()
    local value = lib.callback.await('city_hospital:duty', false)
    if value == nil then return end

    exports.qbx_core:Notify(locale(value and 'notify_duty_on' or 'notify_duty_off'), 'inform')
end

local function openGarage(index)
    local garage = Config.Garages[index]
    local grade = job().grade.level
    local options = {}

    for _, entry in ipairs(Config.Vehicles[garage.kind] or {}) do
        if grade >= entry.grade then
            options[#options + 1] = {
                title = entry.label,
                icon = garage.kind == 'heli' and 'helicopter' or 'truck-medical',
                onSelect = function()
                    local _, reason = lib.callback.await('city_hospital:spawnVehicle', false, index, entry.model)
                    if reason == 'vehicle_out' then exports.qbx_core:Notify(locale('notify_vehicle_out'), 'error') end
                end,
            }
        end
    end

    lib.registerContext({ id = 'city_hospital_garage', title = locale('menu_garage'), options = options })
    lib.showContext('city_hospital_garage')
end

local function storeVehicle()
    local stored = lib.callback.await('city_hospital:storeVehicle', false)
    exports.qbx_core:Notify(locale(stored and 'notify_stored' or 'notify_no_vehicle'), stored and 'success' or 'error')
end

local function teleport(spot)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(cache.ped, spot.x, spot.y, spot.z, false, false, false, false)
    SetEntityHeading(cache.ped, spot.w)
    Wait(300)
    DoScreenFadeIn(600)
end

local function minutes(seconds)
    return seconds < 60 and ('%ds'):format(seconds) or ('%dm'):format(math.floor(seconds / 60))
end

local function openCalls()
    if not onDuty() then return end

    local calls = lib.callback.await('city_hospital:calls', false)
    if not calls or #calls == 0 then return exports.qbx_core:Notify(locale('notify_no_calls'), 'inform') end

    local options = {}

    for _, call in ipairs(calls) do
        options[#options + 1] = {
            title = call.text,
            description = call.acceptedBy and locale('menu_call_taken', minutes(call.ago), call.acceptedBy)
                or locale('menu_call_desc', minutes(call.ago)),
            icon = 'truck-medical',
            onSelect = function()
                local coords = lib.callback.await('city_hospital:acceptCall', false, call.id)
                if coords then SetNewWaypoint(coords.x, coords.y) end
            end,
        }
    end

    lib.registerContext({ id = 'city_hospital_calls', title = locale('menu_calls'), options = options })
    lib.showContext('city_hospital_calls')
end

RegisterCommand('emscalls', openCalls, false)
TriggerEvent('chat:addSuggestion', '/emscalls', locale('command_calls'))

RegisterNetEvent('city_hospital:client:newCall', function(call)
    if GetInvokingResource() or type(call) ~= 'table' then return end

    exports.qbx_core:Notify(locale('notify_new_call', call.text), 'inform')

    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(call.text)
    EndTextCommandSetBlipName(blip)
    callBlips[call.id] = blip

    SetTimeout(CALL_BLIP_MS, function()
        if callBlips[call.id] then RemoveBlip(callBlips[call.id]) end
        callBlips[call.id] = nil
    end)
end)

RegisterNetEvent('city_hospital:client:callClosed', function(id)
    if GetInvokingResource() then return end

    if callBlips[id] then RemoveBlip(callBlips[id]) end
    callBlips[id] = nil
    exports.qbx_core:Notify(locale('notify_call_closed'), 'inform')
end)

for _, coords in ipairs(Config.Duty) do
    zone(coords, { {
        name = 'city_hospital:duty', label = locale('target_duty'), icon = 'fas fa-clipboard-user',
        canInteract = isEms, onSelect = toggleDuty,
    } })
end

for index, coords in ipairs(Config.Armory) do
    zone(coords, { {
        name = 'city_hospital:armory', label = locale('target_armory'), icon = 'fas fa-briefcase-medical',
        canInteract = onDuty,
        onSelect = function() exports.city_inventory:openInventory('shop', { type = 'CityEmsArmory', id = index }) end,
    } })
end

for _, coords in ipairs(Config.Lockers) do
    zone(coords, { {
        name = 'city_hospital:locker', label = locale('target_locker'), icon = 'fas fa-box-archive',
        canInteract = isEms,
        onSelect = function() exports.city_inventory:openInventory('stash', 'city_ems_locker') end,
    } })
end

for index, garage in ipairs(Config.Garages) do
    zone(garage.menu, {
        {
            name = 'city_hospital:garage', label = locale('target_garage'), icon = 'fas fa-warehouse',
            canInteract = onDuty, onSelect = function() openGarage(index) end,
        },
        {
            name = 'city_hospital:store', label = locale('target_store'), icon = 'fas fa-square-parking',
            canInteract = onDuty, onSelect = storeVehicle,
        },
    })
end

for _, elevator in ipairs(Config.Elevators) do
    zone(elevator.main.xyz, { {
        name = 'city_hospital:roof', label = locale('target_roof'), icon = 'fas fa-elevator',
        canInteract = isEms, onSelect = function() teleport(elevator.roof) end,
    } })
    zone(elevator.roof.xyz, { {
        name = 'city_hospital:main', label = locale('target_main'), icon = 'fas fa-elevator',
        canInteract = isEms, onSelect = function() teleport(elevator.main) end,
    } })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    for _, blip in pairs(callBlips) do RemoveBlip(blip) end
end)
