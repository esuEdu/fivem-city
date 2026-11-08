-- Fishing on this client: rod in hand, power bar, cast, wait, bite, and the minigame page. The loop below runs every
-- frame only while the rod is out; the server decides everything that has value.
local water = require 'client.water'
local theme = require '@city_ui.theme'

local fishing
local holding = false

local function help(key)
    lib.showTextUI(locale(key), { position = 'left-center' })
end

local function hideHelp()
    if lib.isTextUIOpen() then lib.hideTextUI() end
end

---@param level integer
---@return number
local function castRange(level)
    local range = Config.CastRange

    for _, at in ipairs(Config.CastRangeLevels) do
        if level >= at then range = range + 1.0 end
    end

    return range
end

local function playIdle()
    lib.requestAnimDict(Config.Anim.dict)
    TaskPlayAnim(cache.ped, Config.Anim.dict, Config.Anim.clip, 2.0, 2.0, -1, 49, 0, false, false, false)
    RemoveAnimDict(Config.Anim.dict)
end

local function attachRod()
    lib.requestModel(Config.RodProp)

    local coords = GetEntityCoords(cache.ped)
    local prop = CreateObject(Config.RodProp, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(Config.RodProp)
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 18905), 0.1, 0.05, 0.0, 80.0, 120.0, 160.0, true, true, false, true, 1, true)

    return prop
end

local function stop()
    if not fishing then return end

    if fishing.state == 'minigame' or fishing.state == 'charging' or fishing.state == 'bite' then
        SendNUIMessage({ action = 'hide' })
    end

    if DoesEntityExist(fishing.prop) then DeleteEntity(fishing.prop) end
    ClearPedTasks(cache.ped)
    hideHelp()

    fishing = nil
    holding = false
    TriggerServerEvent('city_fishing:server:stop')
end

---@param key string
local function failed(key)
    if key then lib.notify({ description = locale(key), type = 'error' }) end
end

---After a cast or a missed bite: wait, then show the bite.
---@param castId integer
---@param waitMs integer
local function waitForBite(castId, waitMs)
    fishing.state = 'waiting'
    fishing.cast = castId
    fishing.biteAt = GetGameTimer() + waitMs
    help('help_waiting')
end

local function cast(power)
    local distance = math.max(2.0, castRange(fishing.level) * power)
    local bobber = water.ahead(distance)

    if not bobber then
        fishing.state = 'idle'
        help('help_idle')
        return failed('cast_no_water')
    end

    fishing.state = 'busy'
    local shore = water.shore(bobber, Config.ShoreBand)
    local ok, result = lib.callback.await('city_fishing:cast', false, fishing.slot, { x = bobber.x, y = bobber.y, z = bobber.z }, shore)

    if not fishing then return end

    if not ok then
        fishing.state = 'idle'
        help('help_idle')
        return failed(result)
    end

    fishing.bobber = bobber
    waitForBite(result.cast, result.waitMs)
end

local function bite()
    fishing.state = 'bite'
    fishing.biteEnds = GetGameTimer() + math.floor(Config.HookWindow * 1000)
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    SendNUIMessage({ action = 'bite' })
end

local function missed()
    SendNUIMessage({ action = 'hide' })
    lib.notify({ description = locale('bite_missed'), type = 'inform' })

    fishing.state = 'busy'
    local ok, waitMs = lib.callback.await('city_fishing:rebite', false, fishing.cast)
    if not fishing then return end

    if ok then return waitForBite(fishing.cast, waitMs) end

    fishing.state = 'idle'
    help('help_idle')
end

---@param result table server's answer to a finished catch
local function showResult(result)
    if result.kind == 'escaped' then
        lib.notify({ description = locale('fish_escaped'), type = 'error' })
    elseif result.kind == 'lost' then
        return
    elseif result.kind == 'item' then
        lib.notify({ description = locale('caught_item', result.label), type = 'inform' })
    else
        local stars = string.rep('★', result.stars)
        local text = locale('caught_fish', result.count > 1 and ('%dx '):format(result.count) or '', result.label, result.size, stars)
        if result.perfect then text = ('%s · %s'):format(text, locale('perfect')) end
        if result.record then text = ('%s · %s'):format(text, locale('new_record')) end
        if result.loot > 0 then text = ('%s · %s'):format(text, locale('chest_opened')) end

        lib.notify({ description = text, type = 'success', duration = 6000 })
    end

    if result.levelUp then
        lib.notify({ title = locale('level_up_title'), description = locale('level_up', result.levelUp), type = 'success', duration = 8000 })
    end
end

local function hook()
    fishing.state = 'busy'
    SendNUIMessage({ action = 'hide' })

    local ok, result = lib.callback.await('city_fishing:hook', false, fishing.cast)
    if not fishing then return end

    if not ok then
        fishing.state = 'idle'
        help('help_idle')
        return failed(result == 'missed' and 'bite_missed' or nil)
    end

    if result.kind ~= 'fish' then
        showResult(result)
        fishing.state = 'idle'
        help('help_idle')
        return
    end

    fishing.state = 'minigame'
    fishing.session = result.session
    hideHelp()
    SendNUIMessage({ action = 'minigame', data = result, config = Config.Minigame })
end

RegisterNUICallback('minigameDone', function(data, cb)
    cb(1)

    if not fishing or fishing.state ~= 'minigame' or type(data) ~= 'table' then return end

    fishing.state = 'busy'

    local ok, result = lib.callback.await('city_fishing:finish', false, fishing.session, {
        caught = data.caught == true,
        perfect = data.perfect == true,
        chest = data.chest == true,
        outside = tonumber(data.outside) or 0,
        escapes = tonumber(data.escapes) or 0,
    })

    if not fishing then return end

    if ok then showResult(result) end

    fishing.state = 'idle'
    help('help_idle')
end)

---Whether fishing has to stop: dead, swimming, driving or no longer holding the rod's slot.
---@return boolean
local function mustStop()
    if IsEntityDead(cache.ped) or IsPedSwimming(cache.ped) or IsPedRagdoll(cache.ped) then return true end
    if cache.vehicle and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped then return true end

    return false
end

local function loop()
    while fishing do
        Wait(0)

        if mustStop() then
            stop()
            break
        end

        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        local now = GetGameTimer()
        local pressed = IsControlPressed(0, Config.Keys.action)
        local state = fishing.state

        if IsControlJustPressed(0, Config.Keys.stop) and state ~= 'minigame' then
            stop()
            break
        end

        if state == 'idle' and IsControlJustPressed(0, Config.Keys.action) then
            fishing.state = 'charging'
            fishing.chargeStart = now
            hideHelp()
            SendNUIMessage({ action = 'power', value = 0 })
        elseif state == 'charging' then
            -- The bar goes up and down while held, so timing the release matters
            local t = (now - fishing.chargeStart) / (Config.CastSeconds * 1000)
            local power = 1 - math.abs((t % 2) - 1)

            if pressed then
                SendNUIMessage({ action = 'power', value = power })
            else
                fishing.state = 'busy'
                SendNUIMessage({ action = 'hide' })
                CreateThread(function() cast(power) end)
            end
        elseif state == 'waiting' then
            DrawMarker(28, fishing.bobber.x, fishing.bobber.y, fishing.bobber.z + 0.05, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, 255, 80, 60, 200, false, false, 2, false, nil, nil, false)

            if now >= fishing.biteAt then bite() end
        elseif state == 'bite' then
            DrawMarker(28, fishing.bobber.x, fishing.bobber.y, fishing.bobber.z + 0.05, 0, 0, 0, 0, 0, 0, 0.2, 0.2, 0.2, 255, 220, 60, 230, false, false, 2, false, nil, nil, false)

            if IsControlJustPressed(0, Config.Keys.action) then
                fishing.state = 'busy'
                CreateThread(hook)
            elseif now > fishing.biteEnds then
                fishing.state = 'busy'
                CreateThread(missed)
            end
        elseif state == 'minigame' then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)

            if pressed ~= holding then
                holding = pressed
                SendNUIMessage({ action = 'hold', value = pressed })
            end
        end
    end
end

RegisterNetEvent('city_fishing:client:useRod', function(slot, level)
    if GetInvokingResource() then return end

    if fishing then return stop() end
    if mustStop() then return end

    SendNUIMessage({ action = 'theme', data = theme })

    fishing = { slot = slot, level = tonumber(level) or 1, state = 'idle' }
    fishing.prop = attachRod()
    playIdle()
    help('help_idle')

    CreateThread(loop)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    stop()
end)
