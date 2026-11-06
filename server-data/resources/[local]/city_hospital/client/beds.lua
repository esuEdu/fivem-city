-- Hospital beds (lie down to be treated), the NPC reception and the hospital blips. The server claims the bed and
-- decides when the treatment is done; this side plays the animation and the camera.
local RECEPTION_RADIUS = 25.0
local TARGET_RADIUS = 1.2
local LEAVE_KEY = 38

local zones, blips = {}, {}
local current
local receptionPeds = {}

local function stopCam()
    if not current or not current.cam then return end

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(current.cam, false)
    current.cam = nil
end

local function getUp()
    if not current then return end

    local spot = current.spot

    stopCam()
    lib.hideTextUI()
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)

    local side = GetOffsetFromEntityInWorldCoords(cache.ped, 1.0, 0.0, 0.0)
    SetEntityCoords(cache.ped, side.x, side.y, spot.z, false, false, false, false)

    current = nil
    lib.callback.await('city_hospital:leaveBed', false)
end

---@param hospital string
---@param bed integer
---@param wait integer seconds until the server heals the player
local function layDown(hospital, bed, wait)
    local spot = Config.Hospitals[hospital].beds[bed].coords
    local anim = Config.Anims.bed

    current = { spot = spot }

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    SetEntityCoords(cache.ped, spot.x, spot.y, spot.z + 0.02, false, false, false, false)
    SetEntityHeading(cache.ped, spot.w)
    FreezeEntityPosition(cache.ped, true)

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, 1.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(anim.dict)

    -- The camera qbx_ambulancejob used: above the bed, looking down at the player
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    AttachCamToPedBone(cam, cache.ped, 31085, 0, 1.0, 1.0, true)
    SetCamFov(cam, 90.0)
    SetCamRot(cam, -45.0, 0.0, GetEntityHeading(cache.ped) + 180.0, 2)
    RenderScriptCams(true, false, 0, true, true)
    current.cam = cam

    DoScreenFadeIn(800)
    lib.showTextUI(locale('text_leave_bed'))

    CreateThread(function()
        local doneAt = GetGameTimer() + wait * 1000 + 500

        while current do
            -- Getting up early: no treatment, nothing charged for lying down
            if IsControlJustPressed(0, LEAVE_KEY) then return getUp() end

            if GetGameTimer() >= doneAt then
                if lib.callback.await('city_hospital:bedDone', false) then
                    exports.qbx_core:Notify(locale('notify_healed'), 'success')
                    return getUp()
                end

                doneAt = GetGameTimer() + 2000
            end

            Wait(0)
        end
    end)
end

-- After a hospital respawn: straight into a bed (qbx_medical's revive must land first)
RegisterNetEvent('city_hospital:client:toBed', function(hospital, bed, wait)
    if GetInvokingResource() or not Config.Hospitals[hospital] then return end

    Wait(500)
    layDown(hospital, bed, wait)
end)

-- No free bed: wake up at the reception, already healed by the server
RegisterNetEvent('city_hospital:client:toReception', function(hospital)
    if GetInvokingResource() or not Config.Hospitals[hospital] then return end

    local spot = Config.Hospitals[hospital].reception
    local front = spot.xyz + vec3(math.cos(math.rad(spot.w + 90.0)), math.sin(math.rad(spot.w + 90.0)), 0.0) * 1.5

    Wait(500)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(cache.ped, front.x, front.y, front.z, false, false, false, false)
    DoScreenFadeIn(800)
end)

local function lieDown(hospital, bed)
    if current or LocalPlayer.state.isDead then return end

    local ok, wait = lib.callback.await('city_hospital:lieDown', false, hospital, bed)
    if not ok then return exports.qbx_core:Notify(locale('notify_bed_taken'), 'error') end

    layDown(hospital, bed, wait)
end

local function checkIn(hospital)
    if current or LocalPlayer.state.isDead then return end

    local ok, bedOrReason, wait = lib.callback.await('city_hospital:checkIn', false, hospital)

    if not ok then
        local key = bedOrReason == 'ems_called' and 'notify_ems_called' or 'notify_no_bed'
        return exports.qbx_core:Notify(locale(key), bedOrReason == 'ems_called' and 'inform' or 'error')
    end

    layDown(hospital, bedOrReason, wait)
end

-- The receptionist only exists while someone is near
local function receptionPoint(name, hospital)
    local spot = hospital.reception

    lib.points.new({
        coords = spot.xyz,
        distance = RECEPTION_RADIUS,
        onEnter = function()
            lib.requestModel(hospital.receptionist)
            local ped = CreatePed(4, hospital.receptionist, spot.x, spot.y, spot.z - 1.0, spot.w, false, true)
            SetModelAsNoLongerNeeded(hospital.receptionist)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)

            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'city_hospital:checkin',
                    label = locale('target_check_in'),
                    icon = 'fas fa-clipboard',
                    distance = 2.5,
                    onSelect = function() checkIn(name) end,
                },
            })

            receptionPeds[name] = ped
        end,
        onExit = function()
            local ped = receptionPeds[name]
            if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
            receptionPeds[name] = nil
        end,
    })
end

local function addBlip(hospital)
    local blip = AddBlipForCoord(hospital.blip.x, hospital.blip.y, hospital.blip.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(hospital.label)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

for name, hospital in pairs(Config.Hospitals) do
    addBlip(hospital)
    receptionPoint(name, hospital)

    for index, bed in ipairs(hospital.beds) do
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = bed.coords.xyz,
            radius = TARGET_RADIUS,
            options = {
                {
                    name = ('city_hospital:bed:%s:%s'):format(name, index),
                    label = locale('target_lie_down'),
                    icon = 'fas fa-bed',
                    canInteract = function() return not current and not LocalPlayer.state.isDead end,
                    onSelect = function() lieDown(name, index) end,
                },
            },
        })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if current then
        stopCam()
        lib.hideTextUI()
        FreezeEntityPosition(cache.ped, false)
        ClearPedTasks(cache.ped)
    end

    for _, zone in ipairs(zones) do exports.ox_target:removeZone(zone) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(receptionPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
