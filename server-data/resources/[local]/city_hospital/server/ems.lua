-- The EMS job: duty, garage, armory, lockers, and working on a patient (examine, revive, treat, bill).
-- Every action checks the job on duty, the distance and the patient's state here; the client only asks.
local settings = require 'server.config'
local state = require 'server.state'

local spawned = {}
local actions = {}
local lastBill = {}

---@param src integer
---@param coords vector3
---@return boolean
local function at(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= settings.ranges.place
end

---@param list vector3[]
---@param src integer
---@return boolean
local function atAny(list, src)
    for i = 1, #list do
        if at(src, list[i]) then return true end
    end

    return false
end

---@param src integer
---@param target unknown
---@return boolean
local function patientInReach(src, target)
    return type(target) == 'number' and target ~= src and GetPlayerName(target) ~= nil
        and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) <= settings.ranges.interact
end

---@param src integer
---@param action string
---@return boolean
local function needEms(src, action)
    if state.isEms(src) then return true end

    exports.city_economy:Flag(src, 'hospital_not_ems', 2, { action = action })
    return false
end

CreateThread(function()
    exports.city_inventory:RegisterShop('CityEmsArmory', {
        name = 'EMS Armory',
        inventory = settings.armory,
        groups = { [Config.Job] = 0 },
        locations = Config.Armory,
    })

    exports.city_inventory:RegisterStash('city_ems_locker', 'Personal locker', settings.locker.slots, settings.locker.weight, true, { [Config.Job] = 0 }, Config.Lockers)
end)

lib.callback.register('city_hospital:duty', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player or player.PlayerData.job.name ~= Config.Job or not atAny(Config.Duty, src) then return end

    local onDuty = not player.PlayerData.job.onduty

    exports.qbx_core:SetJobDuty(src, onDuty)

    return onDuty
end)

-- Job vehicles: one per player at a time, only from the garage the player stands at, only models for their grade
lib.callback.register('city_hospital:spawnVehicle', function(source, garageIndex, model)
    local src = source
    local garage = type(garageIndex) == 'number' and Config.Garages[garageIndex]

    if not garage or type(model) ~= 'string' or not needEms(src, 'spawnVehicle') then return end
    if not at(src, garage.menu) then return end

    local grade = exports.qbx_core:GetPlayer(src).PlayerData.job.grade.level
    local allowed

    for _, entry in ipairs(Config.Vehicles[garage.kind] or {}) do
        if entry.model == model and grade >= entry.grade then allowed = entry end
    end

    if not allowed then return end
    if spawned[src] and DoesEntityExist(spawned[src]) then return false, 'vehicle_out' end

    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { spawnSource = garage.spawn, model = model, warp = GetPlayerPed(src) })

    if not ok or not netId or not vehicle or vehicle == 0 then return end

    spawned[src] = vehicle
    SetVehicleNumberPlateText(vehicle, ('EMS%04d'):format(math.random(0, 9999)))
    exports.qbx_vehiclekeys:GiveKeys(src, vehicle)

    return netId
end)

lib.callback.register('city_hospital:storeVehicle', function(source)
    local src = source
    local vehicle = spawned[src]

    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle)) > 10.0 then return false end

    DeleteEntity(vehicle)
    spawned[src] = nil

    return true
end)

---@param src integer
---@return boolean
local function leoOnDuty(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    return job ~= nil and job.type == 'leo' and job.onduty == true
end

-- Examining a patient: which body parts are hurt and how much they bleed. Police can too (radial menu "Check Health
-- Status").
lib.callback.register('city_hospital:examine', function(source, target)
    local src = source

    if not leoOnDuty(src) and not needEms(src, 'examine') then return end
    if not patientInReach(src, target) then return end

    return exports.qbx_medical:GetPlayerStatus(target)
end)

-- Revive and treat are two steps: start (checks and remembers when), finish (checks the time, then uses the item)
local KINDS = {
    revive = { item = 'firstaid', time = settings.times.emsRevive, needsDown = true },
    treat = { item = 'bandage', time = settings.times.emsTreat, needsDown = false },
}

lib.callback.register('city_hospital:startAction', function(source, kind, target)
    local src = source
    local def = KINDS[kind]

    if not def or not needEms(src, kind) or not patientInReach(src, target) then return false end
    if def.needsDown and not state.down(target) then return false, 'not_down' end
    if state.isFinalized(target) then return false, 'finalized' end
    if exports.city_inventory:GetItemCount(src, def.item) < 1 then return false, 'no_item' end

    actions[src] = { kind = kind, target = target, since = os.time() }

    return true
end)

lib.callback.register('city_hospital:finishAction', function(source)
    local src = source
    local action = actions[src]

    actions[src] = nil

    if not action or not needEms(src, action.kind) or not patientInReach(src, action.target) then return false end

    local def = KINDS[action.kind]

    if os.time() - action.since < def.time then return false end
    if state.isFinalized(action.target) then return false, 'finalized' end
    if def.needsDown and not state.down(action.target) then return false end

    -- The item goes first; no item, no treatment
    if not exports.city_inventory:RemoveItem(src, def.item, 1) then return false, 'no_item' end

    if action.kind == 'revive' then
        exports.qbx_medical:Revive(action.target)
    else
        exports.qbx_medical:HealPartially(action.target)
    end

    return true
end)

-- Billing a patient: a bill in their bank's Billing tab, paid into the EMS job account
lib.callback.register('city_hospital:bill', function(source, target, amount, note)
    local src = source

    if not needEms(src, 'bill') or not patientInReach(src, target) then return false end

    amount = type(amount) == 'number' and math.tointeger(amount)

    if not amount or amount <= 0 or amount > settings.prices.maxBill then return false, 'bad_amount' end
    if lastBill[src] and os.time() - lastBill[src] < settings.times.billCooldown then return false, 'busy' end

    lastBill[src] = os.time()

    local label = type(note) == 'string' and #note > 0 and ('EMS: %s'):format(note:sub(1, 60)) or 'EMS treatment'

    return exports.city_bank:CreateBill(target, amount, label, src)
end)

AddEventHandler('playerDropped', function()
    local src = source

    if spawned[src] and DoesEntityExist(spawned[src]) then DeleteEntity(spawned[src]) end

    spawned[src], actions[src], lastBill[src] = nil, nil, nil
end)
