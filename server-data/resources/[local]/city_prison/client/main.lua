-- Going in and out: teleports, the uniform, the sentence counter on screen, the prison blip and the release desk.
-- Everything here follows the server (city_prison:client:* events); the client decides nothing.
lib.locale()

local theme = require '@city_ui.theme'

local inPrison = false
local months = 0
local blip
local deskZone

local function counter()
    SendNUIMessage({
        action = 'counter',
        visible = inPrison,
        text = months > 0 and locale('counter_months', months) or locale('counter_done'),
        done = months == 0,
        label = locale('counter_label'),
    })
end

local function teleport(coords)
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(25) end

    local ped = cache.ped
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 0.9, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    FreezeEntityPosition(ped, true)

    local deadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(50) end

    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(600)
end

local function wearUniform()
    local outfit = IsPedModel(cache.ped, `mp_f_freemode_01`) and Config.Uniform.female or Config.Uniform.male

    for component, variation in pairs(outfit) do
        SetPedComponentVariation(cache.ped, component, variation[1], variation[2], 0)
    end
end

local function setInside(value)
    inPrison = value
    TriggerEvent('city_prison:client:inside', value)
    counter()
end

RegisterNetEvent('city_prison:client:enter', function(spawn, left)
    if GetInvokingResource() then return end

    months = math.tointeger(left) or 0

    if spawn and Config.Spawns[spawn] then
        teleport(Config.Spawns[spawn])
        lib.notify({ title = locale('welcome_title'), description = locale('welcome_text', months), type = 'inform', duration = 10000 })
    end

    wearUniform()
    setInside(true)
end)

RegisterNetEvent('city_prison:client:time', function(left)
    if GetInvokingResource() then return end

    months = math.tointeger(left) or 0
    counter()
end)

RegisterNetEvent('city_prison:client:released', function()
    if GetInvokingResource() then return end

    setInside(false)
    teleport(Config.Freedom)
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end)

RegisterNetEvent('city_prison:client:escaped', function()
    if GetInvokingResource() then return end

    setInside(false)
end)

RegisterNetEvent('city_prison:client:infirmary', function()
    if GetInvokingResource() then return end

    teleport(Config.Infirmary)
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ theme = theme })
    counter()
end)

local function desk(name)
    local ok, reason = lib.callback.await(name, false)

    if ok then
        if reason == 'partial' then lib.notify({ description = locale('notify_belongings_partial'), type = 'error' }) end
        if name == 'city_prison:collect' and reason ~= 'partial' then lib.notify({ description = locale('notify_belongings_back'), type = 'success' }) end
    elseif reason then
        lib.notify({ description = locale('error_' .. reason), type = 'error' })
    end
end

CreateThread(function()
    local info = Config.Prison.blip
    blip = AddBlipForCoord(info.coords.x, info.coords.y, info.coords.z)
    SetBlipSprite(blip, info.sprite)
    SetBlipColour(blip, info.color)
    SetBlipScale(blip, info.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Prison.label)
    EndTextCommandSetBlipName(blip)

    deskZone = exports.ox_target:addBoxZone({
        coords = Config.Desk.coords,
        size = Config.Desk.size,
        rotation = Config.Desk.rotation,
        options = {
            {
                name = 'city_prison:release',
                icon = 'fas fa-door-open',
                label = locale('target_release'),
                canInteract = function() return inPrison end,
                onSelect = function()
                    if months > 0 then
                        return lib.notify({ description = locale('error_time_left'), type = 'error' })
                    end

                    desk('city_prison:release')
                end,
            },
            {
                name = 'city_prison:collect',
                icon = 'fas fa-box-open',
                label = locale('target_collect'),
                canInteract = function() return not inPrison end,
                onSelect = function() desk('city_prison:collect') end,
            },
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if blip then RemoveBlip(blip) end
    if deskZone then exports.ox_target:removeZone(deskZone) end
end)
