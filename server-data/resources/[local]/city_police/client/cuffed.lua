-- This player's side of being cuffed or escorted: the animation, the blocked controls (only while cuffed), following
-- the officer, being put in or taken out of a car. The server owns the state; this only plays it.

local cuffed = false
local soft = false
local escortedBy = nil
local loopRunning = false

local function playCuffedIdle()
    if not cuffed or QBX.PlayerData.metadata.isdead or QBX.PlayerData.metadata.inlaststand then return end
    if IsEntityPlayingAnim(cache.ped, 'mp_arresting', 'idle', 3) then return end

    lib.playAnim(cache.ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
end

-- Runs only while cuffed or escorted
local function controlLoop()
    if loopRunning then return end
    loopRunning = true

    lib.disableControls:Add(Config.CuffedControls)

    CreateThread(function()
        local tick = 0

        while cuffed or escortedBy do
            lib.disableControls()

            -- Cuffed players walk (no running or jumping); escorted ones follow the officer
            if escortedBy then
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
            end

            tick = tick + 1
            if tick % 60 == 0 then playCuffedIdle() end

            Wait(0)
        end

        lib.disableControls:Remove(Config.CuffedControls)
        loopRunning = false
    end)
end

---@param officer integer server id
local function cuffedAnimation(officer)
    local officerPed = GetPlayerPed(GetPlayerFromServerId(officer))
    if officerPed == 0 or officerPed == cache.ped then return end

    lib.requestAnimDict('mp_arrest_paired')

    local offset = GetOffsetFromEntityInWorldCoords(officerPed, 0.0, 0.45, 0.0)
    SetEntityCoords(cache.ped, offset.x, offset.y, offset.z, true, false, false, false)
    SetEntityHeading(cache.ped, GetEntityHeading(officerPed))
    TaskPlayAnim(cache.ped, 'mp_arrest_paired', 'crook_p2_back_right', 3.0, 3.0, -1, 32, 0, false, false, false)
    Wait(2500)
    RemoveAnimDict('mp_arrest_paired')
end

local function stopEscorted()
    escortedBy = nil
    DetachEntity(cache.ped, true, false)
    TriggerEvent('hospital:client:isEscorted', false)
end

RegisterNetEvent('city_police:client:cuffed', function(on, isSoft, officer)
    if GetInvokingResource() then return end

    if on then
        cuffed, soft = true, isSoft == true
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
        ClearPedTasksImmediately(cache.ped)

        if officer and officer > 0 then cuffedAnimation(officer) end
        playCuffedIdle()
        controlLoop()

        exports.qbx_core:Notify(locale(soft and 'you_softcuffed' or 'you_cuffed'), 'inform')

        -- A soft cuff can be slipped right away, if the skill check goes well
        if soft and lib.skillCheck({ 'medium', 'hard', 'medium' }, { 'w', 'a', 's', 'd' }) then
            TriggerServerEvent('city_police:server:breakCuffs')
        end
    else
        cuffed, soft = false, false
        stopEscorted()
        ClearPedTasks(cache.ped)
        exports.qbx_core:Notify(locale('you_uncuffed'), 'inform')
    end
end)

RegisterNetEvent('city_police:client:escorted', function(on, officer)
    if GetInvokingResource() then return end

    if not on then return stopEscorted() end

    local officerPed = GetPlayerPed(GetPlayerFromServerId(officer))
    if officerPed == 0 then return end

    escortedBy = officer
    AttachEntityToEntity(cache.ped, officerPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    TriggerEvent('hospital:client:isEscorted', true)
    controlLoop()
end)

-- The officer's side: a key (and a hint) to let go, since Alt can't reach the escorted player
local escorting = nil

local stopEscortKey = lib.addKeybind({
    name = 'policestopescort',
    description = locale('keybind_stop_escort'),
    defaultKey = Config.Keys.stopEscort,
    disabled = true,
    onPressed = function()
        if not escorting then return end

        local ok, result = lib.callback.await('city_police:escort', false, escorting)
        if not ok and result then exports.qbx_core:Notify(locale(('error_%s'):format(result)), 'error') end
    end,
})

RegisterNetEvent('city_police:client:escorting', function(on, target)
    if GetInvokingResource() then return end

    escorting = on and math.type(target) == 'integer' and target or nil
    stopEscortKey:disable(not escorting)

    if escorting then
        lib.showTextUI(locale('stop_escort_hint', stopEscortKey:getCurrentKey()))
    else
        lib.hideTextUI()
    end

    TriggerEvent('hospital:client:SetEscortingState', escorting ~= nil)
end)

RegisterNetEvent('city_police:client:enterVehicle', function(netId, seat)
    if GetInvokingResource() or not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local vehicle = NetToVeh(netId)
    stopEscorted()

    -- The seat the officer picked, if it's a passenger seat and still free
    if math.type(seat) == 'integer' and seat >= 0 and IsVehicleSeatFree(vehicle, seat) then
        TaskWarpPedIntoVehicle(cache.ped, vehicle, seat)
        return
    end

    -- Back seats first, then any free one
    for seat = GetVehicleMaxNumberOfPassengers(vehicle) - 1, 0, -1 do
        if IsVehicleSeatFree(vehicle, seat) then
            TaskWarpPedIntoVehicle(cache.ped, vehicle, seat)
            return
        end
    end
end)

RegisterNetEvent('city_police:client:leaveVehicle', function()
    if GetInvokingResource() or not cache.vehicle then return end

    TaskLeaveVehicle(cache.ped, cache.vehicle, 16)
    Wait(800)
    playCuffedIdle()
end)

-- Cuffed when the character loaded (relogged while cuffed)
local function restore()
    cuffed = QBX.PlayerData.metadata and QBX.PlayerData.metadata.ishandcuffed == true
    soft = false

    if cuffed then
        playCuffedIdle()
        controlLoop()
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', restore)

-- qbx_medical stops the escort when the player goes down
AddEventHandler('police:client:DeEscort', function()
    if not escortedBy then return end

    stopEscorted()
    TriggerServerEvent('city_police:server:escortEnded')
end)

-- qbx_medical takes the cuffs off a player who goes down (GetCuffed with -1)
AddEventHandler('police:client:GetCuffed', function()
    if GetInvokingResource() ~= 'qbx_medical' or not cuffed then return end

    TriggerServerEvent('city_police:server:downUncuff')
end)

exports('IsHandcuffed', function()
    return cuffed
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if escortedBy then DetachEntity(cache.ped, true, false) end
    if escorting then lib.hideTextUI() end
    cuffed, escortedBy, escorting = false, nil, nil
end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then restore() end
end)
