-- Carrying a downed body over the shoulder. The server pairs carrier and body; each side plays its own animation, and
-- the body attaches itself to the carrier.
local carryingBody = false
local carried = false

local function stopCarrying()
    if not carryingBody then return end

    carryingBody = false
    lib.hideTextUI()
    StopAnimTask(cache.ped, Config.Anims.carry.dict, Config.Anims.carry.clip, 1.0)
end

local function stopBeingCarried()
    if not carried then return end

    carried = false
    DetachEntity(cache.ped, true, false)
    StopAnimTask(cache.ped, Config.Anims.carried.dict, Config.Anims.carried.clip, 1.0)
    TriggerEvent('hospital:client:isEscorted', false)

    if exports.qbx_medical:IsDead() then exports.qbx_medical:PlayDeadAnimation() end
end

local function loopAnim(anim, flag)
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, -1, flag, 0, false, false, false)
end

-- From the ox_target "Carry" option
AddEventHandler('city_hospital:client:carry', function(target)
    if carryingBody or carried or LocalPlayer.state.isDead then return end
    if not lib.callback.await('city_hospital:carry', false, target) then return end

    carryingBody = true
    lib.showTextUI(locale('text_drop_body'))

    CreateThread(function()
        local anim = Config.Anims.carry

        while carryingBody do
            if not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then loopAnim(anim, 49) end

            -- No weapons or sprinting with a body on the shoulder
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)

            if IsControlJustPressed(0, Config.Keys.dropBody) or LocalPlayer.state.isDead then
                lib.callback.await('city_hospital:drop', false)
                stopCarrying()
            end

            Wait(0)
        end

        RemoveAnimDict(anim.dict)
    end)
end)

RegisterNetEvent('city_hospital:client:beCarried', function(carrier)
    if GetInvokingResource() or type(carrier) ~= 'number' then return end

    local carrierPlayer = GetPlayerFromServerId(carrier)
    if carrierPlayer == -1 then return end

    carried = true
    -- Stops qbx_medical replaying its downed animation every frame
    TriggerEvent('hospital:client:isEscorted', true)

    CreateThread(function()
        local anim = Config.Anims.carried

        AttachEntityToEntity(cache.ped, GetPlayerPed(carrierPlayer), 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)

        while carried do
            if not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then loopAnim(anim, 33) end
            Wait(500)
        end

        RemoveAnimDict(anim.dict)
    end)
end)

RegisterNetEvent('city_hospital:client:carryStop', function()
    if GetInvokingResource() then return end

    stopCarrying()
    stopBeingCarried()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    stopCarrying()
    stopBeingCarried()
end)
