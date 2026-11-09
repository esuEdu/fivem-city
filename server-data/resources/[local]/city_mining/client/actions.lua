-- What the player does at a spot: mine a vein (strike minigame), pan gravel (band minigame) or set a dynamite.
-- The loop runs every frame only during a minigame; the server decides what every action gives.
local theme = require '@city_ui.theme'

local actions = {}

local busy = false
local game -- { kind, session, done }

local function itemLabel(name)
    local item = exports.city_inventory:Items(name)
    return item and item.label or name
end

---@param key string?
---@param ... any
local function fail(key, ...)
    if key then lib.notify({ description = locale(key, ...), type = 'error' }) end
end

---@param drops { item: string, count: integer }[]
---@return string
local function dropText(drops)
    local parts = {}
    for _, drop in ipairs(drops) do parts[#parts + 1] = ('%dx %s'):format(drop.count, itemLabel(drop.item)) end

    return table.concat(parts, ', ')
end

---@param result table
function actions.showDrops(result)
    lib.notify({ description = locale('got_items', dropText(result.drops)), type = 'success', duration = 6000 })

    if result.tired then lib.notify({ description = locale('tired'), type = 'inform' }) end
    if result.levelUp then
        lib.notify({ title = locale('level_up_title'), description = locale('level_up', result.levelUp), type = 'success', duration = 8000 })
    end
end

local function attach(model, bone, offset, rotation)
    lib.requestModel(model)
    local coords = GetEntityCoords(cache.ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, bone), offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)

    return prop
end

local function play(anim, flag)
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, flag, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function stop()
    if game and game.prop and DoesEntityExist(game.prop) then DeleteEntity(game.prop) end
    ClearPedTasks(cache.ped)
    SendNUIMessage({ action = 'hide' })
    if lib.isTextUIOpen() then lib.hideTextUI() end

    game = nil
    busy = false
end

---@return boolean
local function mustStop()
    return IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped) or IsPedSwimming(cache.ped) or (cache.vehicle or false) ~= false
end

local function cancel()
    stop()
    TriggerServerEvent('city_mining:server:stop')
end

-- Runs while a minigame is open: keys go to the page, leaving or getting hurt cancels
local function loop()
    local holding = false

    while game and not game.done do
        Wait(0)

        if mustStop() then return cancel() end

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisablePlayerFiring(cache.playerId, true)

        if IsControlJustPressed(0, 73) then return cancel() end -- X

        if game.kind == 'vein' then
            if IsControlJustPressed(0, Config.Keys.action) then
                SendNUIMessage({ action = 'press' })
                play(Config.MineAnim, 0)
            end
        else
            local pressed = IsControlPressed(0, Config.Keys.action)
            if pressed ~= holding then
                holding = pressed
                SendNUIMessage({ action = 'hold', value = pressed })
            end
        end
    end
end

---@param id integer vein point id
function actions.mine(id)
    if busy then return end
    busy = true

    local ok, result, extra = lib.callback.await('city_mining:start', false, id)
    if not ok then
        busy = false
        return fail(result, extra)
    end

    game = { kind = 'vein', session = result.session }
    game.prop = attach(Config.Pickaxe.prop, Config.Pickaxe.bone, Config.Pickaxe.offset, Config.Pickaxe.rotation)

    SendNUIMessage({ action = 'theme', data = theme })
    SendNUIMessage({
        action = 'strikes',
        data = {
            label = locale('mining_vein', itemLabel(result.ore)),
            hint = locale('help_strike'),
            strikes = Config.Minigame.strikes,
            sweep = Config.Minigame.sweepSeconds * result.factor,
            zone = Config.Minigame.zone,
            perfect = Config.Minigame.perfect,
            -- The page waits at least this long, so the server's minimum time is met
            minSeconds = Config.Minigame.minSeconds * result.factor,
        },
    })

    CreateThread(loop)
end

RegisterNUICallback('strikesDone', function(data, cb)
    cb(1)
    if not game or game.kind ~= 'vein' or game.done then return end

    game.done = true
    local session = game.session
    stop()

    local ok, result = lib.callback.await('city_mining:finish', false, session, type(data) == 'table' and tonumber(data.perfect) or 0)
    if ok then actions.showDrops(result) else fail(result) end
end)

---@param id integer gravel point id
function actions.pan(id)
    if busy then return end
    busy = true

    local ok, result = lib.callback.await('city_mining:panStart', false, id)
    if not ok then
        busy = false
        return fail(result)
    end

    game = { kind = 'pan', session = result.session }
    game.prop = attach(Config.PanProp, 18905, vec3(0.12, 0.02, 0.0), vec3(-90.0, 0.0, 0.0))
    play(Config.PanAnim, 1)

    SendNUIMessage({ action = 'theme', data = theme })
    SendNUIMessage({
        action = 'pan',
        data = {
            label = locale('panning'),
            hint = locale('help_pan'),
            seconds = Config.PanGame.seconds * result.factor,
            band = Config.PanGame.band,
            drift = Config.PanGame.drift,
        },
    })

    CreateThread(loop)
end

RegisterNUICallback('panDone', function(data, cb)
    cb(1)
    if not game or game.kind ~= 'pan' or game.done then return end

    game.done = true
    local session = game.session
    stop()

    local ok, result = lib.callback.await('city_mining:panFinish', false, session, type(data) == 'table' and tonumber(data.kept) or 0)
    if ok then actions.showDrops(result) else fail(result) end
end)

---@param kind string 'super' or 'passage'
---@param region string
function actions.dynamite(kind, region)
    if busy then return end

    local item = exports.city_inventory:GetItemCount('dynamite') or 0
    local homemade = exports.city_inventory:GetItemCount('homemade_dynamite') or 0
    if item + homemade == 0 then return fail('no_dynamite') end

    busy = true

    local done = lib.progressBar({
        duration = 4000,
        label = locale('placing_dynamite'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@thermal_charge', clip = 'thermal_charge' },
    })

    if not done then
        busy = false
        return
    end

    local ok, result = lib.callback.await('city_mining:blast', false, kind, region)
    busy = false

    if not ok then return fail(result) end
    if result and result.drops then actions.showDrops(result) end
    if result and result.opened then lib.notify({ description = locale('passage_opened'), type = 'success' }) end
end

function actions.busy()
    return busy
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and game then stop() end
end)

return actions
