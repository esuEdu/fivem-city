lib.locale()

local theme = require '@city_ui.theme'

local active = false
local choosing = false
local spots = {}
local camera

local function fadeOut(ms)
    DoScreenFadeOut(ms)
    while not IsScreenFadedOut() do Wait(0) end
end

local function findSpot(id)
    for i = 1, #spots do
        if spots[i].id == id then return spots[i] end
    end
end

---In front of where the player will face, looking back at the spot
local function cameraFor(coords)
    local heading = math.rad(coords.w or 0.0)
    local target = vec3(coords.x, coords.y, coords.z)
    local forward = vec3(-math.sin(heading), math.cos(heading), 0.0)
    local pos = target + forward * Config.Camera.distance + vec3(0.0, 0.0, Config.Camera.height)

    return pos, target
end

local function preview(spot)
    local pos, target = cameraFor(spot.coords)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, Config.Camera.fov, false, 2)
    PointCamAtCoord(cam, target.x, target.y, target.z + 1.0)
    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)

    local old = camera
    camera = cam

    if old and DoesCamExist(old) and #(GetCamCoord(old) - pos) < Config.Camera.flyMax then
        SetCamActiveWithInterp(cam, old, Config.Camera.blendMs, 1, 1)
        SetTimeout(Config.Camera.blendMs + 100, function()
            if DoesCamExist(old) then DestroyCam(old, false) end
        end)
        return
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    if old and DoesCamExist(old) then DestroyCam(old, false) end
end

local function stopCamera()
    if camera and DoesCamExist(camera) then DestroyCam(camera, false) end
    camera = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
end

local function hidePed(hidden)
    FreezeEntityPosition(cache.ped, hidden)
    SetEntityVisible(cache.ped, not hidden, false)
    SetEntityInvincible(cache.ped, hidden)
end

local function close()
    active = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- Same as city_character's spawn, then wait for the ground before showing the world
local function spawnAt(coords, propertyId)
    stopCamera()
    hidePed(false)

    exports.spawnmanager:spawnPlayer({ x = coords.x, y = coords.y, z = coords.z, heading = coords.w })

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

    if propertyId then
        TriggerServerEvent('qbx_properties:server:enterProperty', { id = propertyId, isSpawn = true })
    end

    local timeout = GetGameTimer() + 5000
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < timeout do Wait(100) end

    DisplayRadar(true)
    DoScreenFadeIn(800)
end

local function choose(id)
    if not active or choosing then return false end
    choosing = true

    local coords, propertyId = lib.callback.await('city_spawn:choose', false, id)
    if not coords then
        choosing = false
        return false
    end

    close()
    fadeOut(500)
    spawnAt(coords, propertyId)
    choosing = false

    return true
end

-- The HUD and radar stay hidden while the picker is up
local function hideHud()
    CreateThread(function()
        while active do
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

local function open()
    if active then return end

    local data = lib.callback.await('city_spawn:open', false)

    -- Already spawned (a resource restart) or nothing to show: where the character was
    if not data or data.forced or not data.spots or #data.spots == 0 then
        local coords, propertyId = lib.callback.await('city_spawn:choose', false, 'last')
        spawnAt(coords or exports.qbx_core:GetPlayerData().position, propertyId)
        return
    end

    spots = data.spots
    active = true

    if not IsScreenFadedOut() then fadeOut(300) end
    hidePed(true)
    DisplayRadar(false)
    hideHud()
    preview(spots[1])

    SendNUIMessage({
        action = 'open',
        theme = theme,
        spots = spots,
        labels = {
            title = locale('title'),
            subtitle = locale('subtitle'),
            confirm = locale('confirm'),
            hint = locale('hint'),
        },
    })
    SetNuiFocus(true, true)

    Wait(300)
    DoScreenFadeIn(600)
end

RegisterNUICallback('preview', function(data, cb)
    cb(1)
    if not active or type(data) ~= 'table' or type(data.id) ~= 'string' then return end

    local spot = findSpot(data.id)
    if spot then preview(spot) end
end)

RegisterNUICallback('choose', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' or not findSpot(data.id) then return cb(false) end

    -- choose waits on the server and the fade; answer the page first
    cb(true)
    CreateThread(function()
        if not choose(data.id) then SendNUIMessage({ action = 'unlock' }) end
    end)
end)

---city_character calls this once an existing character is loaded
exports('Open', function()
    CreateThread(open)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not active then return end

    close()
    stopCamera()
    hidePed(false)
    DisplayRadar(true)
    DoScreenFadeIn(0)
end)
