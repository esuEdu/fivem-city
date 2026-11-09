-- Blasts, cave-ins (warning, damage, being trapped and dug out), planting dynamite, the sluice box, the helmet lamp,
-- the boots and the Geologist's vein tracking.
local places = require 'client.places'

-- Blasts: a visual explosion that hurts nobody (the server already decided what it did)
RegisterNetEvent('city_mining:client:blast', function(at, damage)
    if GetInvokingResource() then return end

    if at then
        local coords = vec3(at.x, at.y, at.z)
        if #(GetEntityCoords(cache.ped) - coords) < 250.0 then
            AddExplosion(coords.x, coords.y, coords.z, 7, 0.0, true, false, 1.0, true)
            ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', 0.4)
        end
    end

    if type(damage) == 'number' and damage > 0 then
        local self = GetEntityCoords(cache.ped)
        AddExplosion(self.x, self.y, self.z, 7, 0.0, true, false, 1.0, true)
        SetEntityHealth(cache.ped, math.max(101, GetEntityHealth(cache.ped) - damage))
        SetPedToRagdoll(cache.ped, 2500, 2500, 0, false, false, false)
        lib.notify({ description = locale('dynamite_failed'), type = 'error' })
    end
end)

-- Using dynamite anywhere: place it in front, short fuse, then the server checks and sets it off
RegisterNetEvent('city_mining:client:plantDynamite', function(name)
    if GetInvokingResource() or type(name) ~= 'string' then return end

    local done = lib.progressBar({
        duration = 4000,
        label = locale('placing_dynamite'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@thermal_charge', clip = 'thermal_charge' },
    })
    if not done then return end

    local at = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.2, -0.9)
    lib.notify({ description = locale('fuse_lit'), type = 'inform' })
    Wait(5000)

    local ok, result = lib.callback.await('city_mining:plant', false, name, { x = at.x, y = at.y, z = at.z })
    if not ok then lib.notify({ description = locale(result or 'invalid'), type = 'error' }) end
end)

-- Cave-ins
RegisterNetEvent('city_mining:client:caveWarning', function(seconds)
    if GetInvokingResource() then return end

    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    lib.notify({ title = locale('cave_title'), description = locale('cave_warning', tonumber(seconds) or 8), type = 'error', duration = 7000 })
end)

RegisterNetEvent('city_mining:client:caveIn', function(damage)
    if GetInvokingResource() then return end

    ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.6)
    SetEntityHealth(cache.ped, math.max(101, GetEntityHealth(cache.ped) - (tonumber(damage) or 0)))
    SetPedToRagdoll(cache.ped, 3000, 3000, 0, false, false, false)
    lib.notify({ title = locale('cave_title'), description = locale('cave_in'), type = 'error', duration = 8000 })
end)

-- While trapped the player can't move; anyone close can dig them out
local trappedLoop = false

local function holdTrapped()
    if trappedLoop then return end
    trappedLoop = true

    CreateThread(function()
        lib.showTextUI(locale('trapped_help'), { position = 'left-center', icon = 'person-falling' })

        while LocalPlayer.state.miningTrapped do
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            Wait(0)
        end

        if lib.isTextUIOpen() then lib.hideTextUI() end
        trappedLoop = false
    end)
end

AddStateBagChangeHandler('miningTrapped', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then holdTrapped() end
end)

exports.ox_target:addGlobalPlayer({
    {
        name = 'city_mining:rescue',
        icon = 'fa-solid fa-trowel',
        label = locale('target_rescue'),
        distance = 2.5,
        canInteract = function(entity)
            local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
            return Player(target).state.miningTrapped ~= nil
        end,
        onSelect = function(data)
            local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            if not lib.progressBar({ duration = 6000, label = locale('rescuing'), canCancel = true, disable = { move = true },
                anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' } }) then return end

            local ok, result = lib.callback.await('city_mining:rescue', false, target)
            places.report(ok, result, 'rescue_done')
        end,
    },
})

-- Sluice box: a prop at the spot while it works (only its owner sees it)
local sluice

RegisterNetEvent('city_mining:client:sluice', function(at)
    if GetInvokingResource() then return end

    if sluice and DoesEntityExist(sluice) then DeleteEntity(sluice) end
    sluice = nil
    if not at then return end

    local model = `prop_wooden_barrel`
    lib.requestModel(model)
    sluice = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(sluice)
    FreezeEntityPosition(sluice, true)
    exports.ox_target:addLocalEntity(sluice, {
        { name = 'city_mining:sluice', icon = 'fa-solid fa-hand', label = locale('target_sluice_stop'), onSelect = function() TriggerServerEvent('city_mining:server:stopSluice') end },
    })
end)

-- Helmet: a hard hat on the head and a lamp in front while it's on
local helmet
local lampLoop = false

local function lamp()
    if lampLoop then return end
    lampLoop = true

    CreateThread(function()
        local light = Config.HelmetLight

        while LocalPlayer.state.miningHelmet do
            local head = GetPedBoneCoords(cache.ped, 31086, 0.15, 0.1, 0.0)
            local forward = GetEntityForwardVector(cache.ped)
            DrawSpotLight(head.x, head.y, head.z, forward.x, forward.y, -0.25, 255, 244, 214, light.distance, light.brightness, 0.0, light.radius, 1.0)
            Wait(0)
        end

        lampLoop = false
    end)
end

---@param on boolean
local function wearHelmet(on)
    if helmet and DoesEntityExist(helmet) then DeleteEntity(helmet) end
    helmet = nil

    if not on then return end

    if IsModelInCdimage(Config.HelmetProp) then
        lib.requestModel(Config.HelmetProp)
        helmet = CreateObject(Config.HelmetProp, 0.0, 0.0, 0.0, true, true, false)
        SetModelAsNoLongerNeeded(Config.HelmetProp)
        AttachEntityToEntity(helmet, cache.ped, GetPedBoneIndex(cache.ped, 31086), 0.13, 0.0, 0.0, 0.0, 270.0, 90.0, true, true, false, true, 1, true)
    end

    lamp()
end

AddStateBagChangeHandler('miningHelmet', ('player:%s'):format(cache.serverId), function(_, _, value)
    wearHelmet(value == true)
end)

-- Every few seconds: the helmet comes off if it left the inventory; the boots speed up a loaded player
CreateThread(function()
    local boosted = false

    while true do
        Wait(2000)

        if LocalPlayer.state.miningHelmet and (exports.city_inventory:GetItemCount('mining_helmet') or 0) == 0 then
            TriggerServerEvent('city_mining:server:helmetGone')
        end

        local loaded = (exports.city_inventory:GetPlayerWeight() or 0) >= 0.6 * 85000
        local boots = loaded and (exports.city_inventory:GetItemCount('mining_boots') or 0) > 0

        if boots ~= boosted then
            boosted = boots
            SetRunSprintMultiplierForPlayer(cache.playerId, boots and 1.1 or 1.0)
        end
    end
end)

-- Tracking (Geologist): nearby veins the player can mine as blips for a minute
local trackBlips = {}

local function clearTracking()
    for _, blip in ipairs(trackBlips) do RemoveBlip(blip) end
    trackBlips = {}
end

local function trackVeins()
    local ok, list = lib.callback.await('city_mining:track', false)
    if not ok then return lib.notify({ description = locale(list or 'invalid'), type = 'error' }) end

    clearTracking()
    for _, vein in ipairs(list) do
        local blip = AddBlipForCoord(vein.x, vein.y, vein.z)
        SetBlipSprite(blip, 618)
        SetBlipColour(blip, vein.tier >= 3 and 46 or 5)
        SetBlipScale(blip, 0.6)
        trackBlips[#trackBlips + 1] = blip
    end

    lib.notify({ description = locale('tracked', #list), type = 'inform' })
    SetTimeout(60000, clearTracking)
end

AddEventHandler('city_mining:client:track', trackVeins)

lib.addKeybind({
    name = 'city_mining_track',
    description = locale('keybind_track'),
    defaultKey = '',
    onPressed = trackVeins,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    clearTracking()
    if sluice and DoesEntityExist(sluice) then DeleteEntity(sluice) end
    if helmet and DoesEntityExist(helmet) then DeleteEntity(helmet) end
    exports.ox_target:removeGlobalPlayer('city_mining:rescue')
end)
