-- Camera mode: the phone closes and the player looks through the camera. Back camera = a scripted first person
-- camera (mouse to aim, wheel to zoom); selfie = the game's own front phone camera. Filters are timecycle modifiers,
-- and the HUD and radar stay hidden so photos come out clean. The photo itself is taken by the server
-- (city_phone_photos:capture), never sent by this client.
local camera = {}

local active = false
local selfie = false
local busy = false
local hideHud = true
local filter = 1
local fov = Config.Fov.default
local pitch = 0.0
local cam

local function overlay(data)
    data = data or {}
    data.action = data.action or 'state'
    SendNUIMessage(data)
end

local function language()
    local settings = exports.city_phone:GetSettings() or {}
    return settings.language
end

local function sendState()
    overlay({
        visible = active,
        selfie = selfie,
        filter = Config.Filters[filter].key,
        zoom = math.floor((Config.Fov.max - fov) / (Config.Fov.max - Config.Fov.min) * 100 + 0.5),
        hud = hideHud,
        language = language(),
    })
end

local function applyFilter()
    local modifier = Config.Filters[filter].modifier
    if modifier then SetTimecycleModifier(modifier) else ClearTimecycleModifier() end
end

local function startBack()
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, true)
    pitch = 0.0
end

local function stopBack()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

-- CELL_CAM_ACTIVATE_SELFIE_MODE: FiveM's Lua has no named function for it, so it is called by its hash
local function selfieMode(on)
    Citizen.InvokeNative(0x2491A93618B7D838, on)
end

local function startSelfie()
    CreateMobilePhone(1)
    CellCamActivate(true, true)
    selfieMode(true)
end

local function stopSelfie()
    selfieMode(false)
    CellCamActivate(false, false)
    DestroyMobilePhone()
end

-- The back camera follows the head; the mouse turns the player and tilts the camera
local function moveBack()
    local ped = cache.ped
    local x = GetDisabledControlNormal(0, 1) * Config.LookSpeed
    local y = GetDisabledControlNormal(0, 2) * Config.LookSpeed

    SetEntityHeading(ped, GetEntityHeading(ped) - x)
    pitch = math.max(Config.Pitch.min, math.min(Config.Pitch.max, pitch - y))

    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local forward = GetEntityForwardVector(ped)
    SetCamCoord(cam, head.x + forward.x * 0.25, head.y + forward.y * 0.25, head.z + 0.05)
    SetCamRot(cam, pitch, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, fov)

    -- Don't see your own body from inside the head
    SetEntityLocallyInvisible(ped)
end

local function toggleSelfie()
    selfie = not selfie

    if selfie then
        stopBack()
        startSelfie()
    else
        stopSelfie()
        startBack()
    end

    sendState()
end

local function shoot()
    if busy then return end
    busy = true

    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
    overlay({ action = 'flash' })

    local id, left = lib.callback.await('city_phone_photos:capture', false)

    if id then
        TriggerEvent('city_phone_photos:client:added')
        overlay({ action = 'saved', left = left, language = language() })
    else
        overlay({ action = 'error', reason = left, language = language() })
    end

    busy = false
end

local function key(name)
    return IsDisabledControlJustPressed(0, Config.Keys[name])
end

local function stop(reopen)
    if not active then return end

    active = false
    if selfie then stopSelfie() else stopBack() end
    selfie = false
    ClearTimecycleModifier()
    sendState()

    if reopen then exports.city_phone:Open() end
end

---One frame of camera mode; returns true when camera mode should end (and whether to reopen the phone)
local function frame()
    -- Leave camera mode on losing the phone or going down
    if LocalPlayer.state.isDead or exports.city_inventory:GetItemCount(Config.Item) < 1 then return true, false end

    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 37, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 199, true)
    DisableControlAction(0, 200, true)

    if not selfie then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        moveBack()
    end

    if hideHud then HideHudAndRadarThisFrame() end

    if key('shoot') or key('shootAlt') then CreateThread(shoot) end
    if key('selfie') then toggleSelfie() end
    if key('hud') then hideHud = not hideHud; sendState() end

    if key('filterLeft') or key('filterRight') then
        filter = (filter - 1 + (key('filterRight') and 1 or -1)) % #Config.Filters + 1
        applyFilter()
        sendState()
    end

    if not selfie and (key('zoomIn') or key('zoomOut')) then
        fov = math.max(Config.Fov.min, math.min(Config.Fov.max, fov + (key('zoomIn') and -Config.Fov.step or Config.Fov.step)))
        sendState()
    end

    -- Backspace, right mouse or Esc (Esc is held back so the pause menu doesn't open)
    if key('exit') or key('exitAlt') or IsDisabledControlJustPressed(0, 200) then return true, true end

    return false
end

-- Any error in a frame ends camera mode instead of leaving the player stuck in it
local function loop()
    while active do
        local ok, finished, reopen = pcall(frame)

        if not ok then
            lib.print.error(('city_phone_camera: %s'):format(finished))
            return stop(true)
        end

        if finished then return stop(reopen) end

        Wait(0)
    end
end

function camera.start()
    if active or LocalPlayer.state.isDead or exports.city_inventory:GetItemCount(Config.Item) < 1 then return end

    exports.city_phone:Close()
    active = true
    selfie = false
    fov = Config.Fov.default
    filter = 1

    Wait(250)
    startBack()
    applyFilter()
    sendState()
    CreateThread(loop)
end

function camera.isActive()
    return active
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then stop(false) end
end)

return camera
