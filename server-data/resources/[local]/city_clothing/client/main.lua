-- Clothing stores and barbers: a clerk ped at each store, the shop page, the preview on the ped and buying
local look = require 'client.look'
local camera = require 'client.camera'
local theme = require '@city_ui.theme'

local RESOURCE = GetCurrentResourceName()

local open = nil ---@type { index: integer, store: table, categories: table[], byId: table, original: table }?
local clerks = {}
local blips = {}

local function notify(text, kind)
    lib.notify({ description = text, type = kind or 'inform' })
end

local function images()
    local ok, index = pcall(json.decode, LoadResourceFile(RESOURCE, 'images/index.json') or '{}')
    return ok and type(index) == 'table' and index or {}
end

---The categories of a store this ped can use, with what the page needs to draw them
local function categoriesFor(storeType, prices)
    local sex = look.sex()
    local list = {}

    for _, category in ipairs(Config.Categories[storeType]) do
        if not category.sex or category.sex == sex then
            list[#list + 1] = {
                id = category.id,
                label = category.label,
                kind = category.kind,
                slot = category.slot,
                shot = category.shot,
                colors = category.colors,
                price = prices[category.id] or 0,
                count = look.count(category),
                value = look.get(category),
            }
        end
    end

    return list
end

local function values()
    local out = {}
    for _, category in ipairs(open.categories) do out[category.id] = look.get(category) end
    return out
end

local function controlsLoop()
    CreateThread(function()
        while open do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

local function close(revert)
    if not open then return end

    if revert then look.restore(open.original) end

    open = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    camera.stop()
    FreezeEntityPosition(cache.ped, false)
    lib.callback('city_clothing:close', false, function() end)
end

local function openStore(index)
    if open then return end

    local store = Config.Stores[index]
    if not store then return end

    if cache.vehicle or IsEntityDead(cache.ped) or LocalPlayer.state.isDead then return end
    if not look.isFreemode() then return notify('The store has nothing in your size.', 'error') end

    local info = lib.callback.await('city_clothing:open', false, index)
    if not info then return notify('The store is closed for you right now.', 'error') end

    open = { index = index, store = store, original = look.snapshot() }
    open.categories = categoriesFor(info.type, info.prices)
    open.byId = {}
    for _, category in ipairs(open.categories) do open.byId[category.id] = category end
    open.baseline = values()

    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, true)
    camera.start()
    camera.setShot(open.categories[1].shot)
    controlsLoop()

    SendNUIMessage({
        action = 'open',
        theme = theme,
        store = info.type,
        sex = look.sex(),
        categories = open.categories,
        palettes = look.palettes(),
        outfits = info.outfits,
        maxOutfits = info.maxOutfits,
        images = images(),
    })
    SetNuiFocus(true, true)
end

-- Page callbacks. Values are checked for shape here; the server checks everything again before saving.
local function isInt(v, min, max)
    return type(v) == 'number' and v == math.floor(v) and v >= min and v <= max
end

local function validValue(category, value)
    if type(value) ~= 'table' then return false end

    if category.kind == 'component' then
        return isInt(value.drawable, 0, 2000) and isInt(value.texture, 0, 255)
    elseif category.kind == 'prop' then
        return isInt(value.drawable, -1, 2000) and isInt(value.texture, -1, 255)
    elseif category.kind == 'hair' then
        return isInt(value.style, 0, 2000) and isInt(value.texture, 0, 255)
            and isInt(value.color, 0, 63) and isInt(value.highlight, 0, 63)
    end

    return isInt(value.style, 0, 255) and type(value.opacity) == 'number' and value.opacity >= 0 and value.opacity <= 1
        and isInt(value.color, 0, 63) and isInt(value.secondColor or 0, 0, 63)
end

RegisterNUICallback('preview', function(data, cb)
    local category = open and type(data) == 'table' and open.byId[data.id]
    if not category or not validValue(category, data.value) then return cb(false) end

    -- Natives want integers; the page's JSON numbers may arrive as floats
    local value = {}
    for key, v in pairs(data.value) do value[key] = key == 'opacity' and v + 0.0 or math.tointeger(v) end

    look.set(category, value)
    cb(true)
end)

RegisterNUICallback('textures', function(data, cb)
    local category = open and type(data) == 'table' and open.byId[data.id]
    local drawable = category and math.tointeger(data.drawable)
    if not drawable then return cb(0) end

    cb(look.textures(category, drawable))
end)

RegisterNUICallback('shot', function(data, cb)
    cb(true)
    if open and type(data) == 'table' then camera.setShot(data.name) end
end)

RegisterNUICallback('zoom', function(data, cb)
    cb(true)
    if open and type(data) == 'table' and type(data.delta) == 'number' then camera.zoom(data.delta) end
end)

RegisterNUICallback('rotate', function(data, cb)
    cb(true)
    if open and type(data) == 'table' and type(data.degrees) == 'number' then camera.rotate(data.degrees) end
end)

local REFUSED = {
    money = 'Not enough money.',
    far = 'You walked away from the store.',
    nothing = 'Nothing to pay for.',
    invalid = 'The store can\'t sell that.',
    busy = 'One moment.',
}

RegisterNUICallback('buy', function(data, cb)
    if not open then return cb({ ok = false }) end

    local account = type(data) == 'table' and data.account
    local ok, result = lib.callback.await('city_clothing:buy', false, look.wanted(open.categories, open.baseline), account)

    if not ok then
        notify(REFUSED[result] or 'The purchase failed.', 'error')
        return cb({ ok = false })
    end

    -- Leaving now keeps what was bought (and a uniform worn over it, as the player came in)
    open.original = look.snapshot()
    open.baseline = values()
    notify(('Paid $%d.'):format(result.total), 'success')
    cb({ ok = true, values = open.baseline })
end)

local function wear(skin)
    look.restore(skin)
    open.original = skin
    open.baseline = values()
end

RegisterNUICallback('saveOutfit', function(data, cb)
    if not open then return cb({ ok = false }) end

    local ok, result = lib.callback.await('city_clothing:saveOutfit', false, type(data) == 'table' and data.name)
    if not ok then
        notify(result == 'full' and 'You can\'t keep more looks.' or 'Couldn\'t save the look.', 'error')
        return cb({ ok = false })
    end

    cb({ ok = true, outfits = result })
end)

RegisterNUICallback('wearOutfit', function(data, cb)
    if not open then return cb({ ok = false }) end

    local ok, skin = lib.callback.await('city_clothing:wearOutfit', false, type(data) == 'table' and data.id)
    if not ok then
        notify('Couldn\'t put that look on.', 'error')
        return cb({ ok = false })
    end

    wear(skin)
    cb({ ok = true, values = values() })
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    if not open then return cb({ ok = false }) end

    local ok, result = lib.callback.await('city_clothing:deleteOutfit', false, type(data) == 'table' and data.id)
    cb({ ok = ok == true, outfits = ok and result or nil })
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    close(true)
end)

-- Clerks are local peds spawned only near their store
local function spawnClerk(index)
    local store = Config.Stores[index]
    local clerk = Config.Clerks[store.type]

    lib.requestModel(clerk.model)
    local ped = CreatePed(4, clerk.model, store.coords.x, store.coords.y, store.coords.z - 1.0, store.coords.w, false, true)
    SetModelAsNoLongerNeeded(clerk.model)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'city_clothing:open',
            label = clerk.label,
            icon = clerk.icon,
            distance = 2.5,
            onSelect = function() openStore(index) end,
        },
    })

    clerks[index] = ped
end

local function removeClerk(index)
    local ped = clerks[index]
    if not ped then return end

    exports.ox_target:removeLocalEntity(ped, 'city_clothing:open')
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    clerks[index] = nil
end

for index, store in ipairs(Config.Stores) do
    lib.points.new({
        coords = store.coords.xyz,
        distance = Config.SpawnDistance,
        onEnter = function() spawnClerk(index) end,
        onExit = function() removeClerk(index) end,
    })

    local blip = Config.Blips[store.type]
    if blip then
        local handle = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
        SetBlipSprite(handle, blip.sprite)
        SetBlipColour(handle, blip.color)
        SetBlipScale(handle, blip.scale)
        SetBlipAsShortRange(handle, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(blip.label)
        EndTextCommandSetBlipName(handle)
        blips[#blips + 1] = handle
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end

    close(true)
    for index in pairs(clerks) do removeClerk(index) end
    for _, handle in ipairs(blips) do RemoveBlip(handle) end
end)
