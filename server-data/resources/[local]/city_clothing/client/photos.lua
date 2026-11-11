-- The photo tool: one picture of every piece the shops sell, for both sexes. The staff member's own ped is dressed in
-- underwear and one piece at a time under a scripted camera; the server takes each picture. Their look comes back after.
local photos = Config.Photos
local STOP_KEY = 194 -- Backspace
local UP = vector3(0.0, 0.0, 1.0)

local running = false
local cam
local target = vector3(0.0, 0.0, 0.0)

local function keyOf(category)
    local prefix = (category.kind == 'prop' and 'p') or (category.kind == 'overlay' and 'o') or 'c'
    return prefix .. category.slot
end

---Every category of every store once, as the pictures are keyed (hair is component 2)
local function shotList()
    local list, seen = {}, {}
    for _, storeType in ipairs({ 'clothing', 'barber' }) do
        for _, category in ipairs(Config.Categories[storeType]) do
            local key = keyOf(category)
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = { key = key, category = category }
            end
        end
    end
    return list
end

local function normalize(v)
    local length = #v
    return length > 0 and v / length or v
end

local function cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

local function polyBothSides(a, b, c, color)
    local r, g, bl = color[1], color[2], color[3]
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, 255)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, 255)
end

-- A plain backdrop behind the ped (facing the camera) and a soft key light, every frame while running
local function drawLoop()
    CreateThread(function()
        while running do
            if cam then
                local from = GetCamCoord(cam)
                local dir = normalize(target - from)
                local right = normalize(cross(dir, UP))
                local up = cross(right, dir)
                local center = target + dir * 0.9
                local size = 4.0

                local tl = center - right * size + up * size
                local tr = center + right * size + up * size
                local bl = center - right * size - up * size
                local br = center + right * size - up * size
                polyBothSides(tl, tr, bl, photos.backdrop)
                polyBothSides(tr, br, bl, photos.backdrop)

                local light = from + up * 0.4 - right * 0.3
                DrawLightWithRange(light.x, light.y, light.z, 255, 250, 240, 4.0, 2.5)
            end

            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            if IsDisabledControlJustPressed(0, STOP_KEY) then running = false end
            Wait(0)
        end
    end)
end

local function aim(shotName)
    local preset = Config.Shots[shotName] or Config.Shots.body
    local ped = cache.ped
    local heading = GetEntityHeading(ped)
    local rad = math.rad(preset.side and heading + 70.0 or heading)
    local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
    if preset.behind then dir = -dir end

    target = GetPedBoneCoords(ped, preset.bone, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, preset.height)
    local from = target + dir * preset.distance

    SetCamCoord(cam, from.x, from.y, from.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamFov(cam, preset.fov)
end

local function setModel(sex)
    local model = sex == 'f' and `mp_f_freemode_01` or `mp_m_freemode_01`
    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)
    cache.ped = PlayerPedId()

    local face = sex == 'f' and 21 or 0
    SetPedHeadBlendData(cache.ped, face, face, 0, face, face, 0, 0.5, 0.5, 0.0, false)
end

local function undress(sex)
    local ped = cache.ped
    for component, drawable in pairs(photos.base[sex]) do SetPedComponentVariation(ped, component, drawable, 0, 0) end
    SetPedComponentVariation(ped, 2, 0, 0, 0)
    ClearAllPedProps(ped)
    for overlay = 0, 12 do SetPedHeadOverlay(ped, overlay, 255, 0.0) end
end

local function placeAtSpot()
    local spot = photos.spot
    local ped = cache.ped

    RequestCollisionAtCoord(spot.x, spot.y, spot.z)
    SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
    SetEntityHeading(ped, spot.w)

    local deadline = GetGameTimer() + 3000
    repeat Wait(0) until HasCollisionLoadedAroundEntity(ped) or GetGameTimer() > deadline

    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
end

local function waitFor(check)
    local deadline = GetGameTimer() + 2000
    while not check() and GetGameTimer() < deadline do Wait(0) end
end

---Dresses the ped in one style of a category, waiting for it to stream in
local function wearPiece(category, drawable)
    local ped, slot = cache.ped, category.slot

    if category.kind == 'component' then
        SetPedPreloadVariationData(ped, slot, drawable, 0)
        waitFor(function() return HasPedPreloadVariationDataFinished(ped) end)
        SetPedComponentVariation(ped, slot, drawable, 0, 0)
        ReleasePedPreloadVariationData(ped)
    elseif category.kind == 'prop' then
        SetPedPreloadPropData(ped, slot, drawable, 0)
        waitFor(function() return HasPedPreloadPropDataFinished(ped) end)
        SetPedPropIndex(ped, slot, drawable, 0, true)
        ReleasePedPreloadPropData(ped)
    elseif category.kind == 'hair' then
        SetPedPreloadVariationData(ped, 2, drawable, 0)
        waitFor(function() return HasPedPreloadVariationDataFinished(ped) end)
        SetPedComponentVariation(ped, 2, drawable, 0, 0)
        SetPedHairColor(ped, photos.hairColor, photos.hairColor)
        ReleasePedPreloadVariationData(ped)
    else
        local colorType = category.colors == 'makeup' and 2 or 1
        local color = colorType == 2 and photos.makeupColor or photos.hairColor
        SetPedHeadOverlay(ped, slot, drawable, 1.0)
        SetPedHeadOverlayColor(ped, slot, colorType, color, color)
    end

    Wait(photos.settleMs)
end

local function takeOff(category, sex)
    local ped, slot = cache.ped, category.slot

    if category.kind == 'component' then
        SetPedComponentVariation(ped, slot, photos.base[sex][slot] or 0, 0, 0)
    elseif category.kind == 'prop' then
        ClearPedProp(ped, slot)
    elseif category.kind == 'hair' then
        SetPedComponentVariation(ped, 2, 0, 0, 0)
    else
        SetPedHeadOverlay(ped, slot, 255, 0.0)
    end
end

local function countOf(category)
    local ped, slot = cache.ped, category.slot
    if category.kind == 'component' then return GetNumberOfPedDrawableVariations(ped, slot) end
    if category.kind == 'prop' then return GetNumberOfPedPropDrawableVariations(ped, slot) end
    if category.kind == 'hair' then return GetNumberOfPedDrawableVariations(ped, 2) end
    return GetPedHeadOverlayNum(slot)
end

local function progress(text)
    lib.showTextUI(('%s  ·  [Backspace] stop'):format(text), { position = 'top-center' })
end

local function run()
    local index = lib.callback.await('city_clothing:photos:index', false)
    if not index then return end

    running = true
    local back = GetEntityCoords(cache.ped)
    local backHeading = GetEntityHeading(cache.ped)
    local list = shotList()
    local taken, failed = 0, 0

    DisplayRadar(false)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    drawLoop()

    for _, sex in ipairs({ 'm', 'f' }) do
        if not running then break end

        setModel(sex)
        placeAtSpot()
        undress(sex)

        for _, shot in ipairs(list) do
            if not running then break end

            local category = shot.category
            if not category.sex or category.sex == sex then
                local count = countOf(category)
                aim(category.shot)

                for drawable = 0, count - 1 do
                    if not running then break end

                    local name = ('%s_%s_%d'):format(sex, shot.key, drawable)
                    if not index[name] then
                        progress(('Photos %s · %s %d/%d · %d taken'):format(sex == 'm' and 'male' or 'female', category.label, drawable + 1, count, taken))
                        wearPiece(category, drawable)
                        aim(category.shot)

                        -- The progress box is page UI; keep it out of the picture
                        lib.hideTextUI()
                        Wait(60)

                        if lib.callback.await('city_clothing:photos:shot', false, sex, shot.key, drawable) then
                            taken = taken + 1
                        else
                            failed = failed + 1
                        end
                    end
                end

                takeOff(category, sex)
            end
        end
    end

    running = false
    lib.hideTextUI()
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil

    TriggerEvent('illenium-appearance:client:reloadSkin', true)
    Wait(1500)

    local ped = PlayerPedId()
    cache.ped = ped
    SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)
    SetEntityHeading(ped, backHeading)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)

    lib.callback.await('city_clothing:photos:finish', false)

    lib.notify({
        type = failed > 0 and 'warning' or 'success',
        duration = 10000,
        description = ('Clothing photos: %d new, %d failed. Run "ensure city_clothing" so the shops show them.'):format(taken, failed),
    })
end

RegisterNetEvent('city_clothing:client:photos', function()
    if GetInvokingResource() or running then return end
    CreateThread(run)
end)
