-- The tuning menu: builds the options from the car in the bay, previews each choice on the car (the mechanic drives
-- it, so they own it), orbits a camera around it and sends the cart to the server on confirm.
local theme = require '@city_ui.theme'
local catalog = require 'shared.catalog'
local colors = require 'shared.colors'
local camera = require 'client.camera'

local tuning = {}

local session

local WHEEL_TYPES = {
    { id = 0, label = 'Sport' }, { id = 1, label = 'Muscle' }, { id = 2, label = 'Lowrider' }, { id = 3, label = 'SUV' },
    { id = 4, label = 'Offroad' }, { id = 5, label = 'Tuner' }, { id = 7, label = 'High End' },
    { id = 8, label = "Benny's Original" }, { id = 9, label = "Benny's Bespoke" }, { id = 10, label = 'Open Wheel' },
    { id = 11, label = 'Street' }, { id = 12, label = 'Track' },
}

local NEONS = {
    { label = 'Off', value = { false, false, false, false } },
    { label = 'Sides', value = { true, true, false, false } },
    { label = 'Front', value = { false, false, true, false } },
    { label = 'Back', value = { false, false, false, true } },
    { label = 'Front and back', value = { false, false, true, true } },
    { label = 'All around', value = { true, true, true, true } },
}

---@param key string
---@param value any
---@return integer
local function price(key, value)
    return catalog.price(key, value, Config.Prices) or 0
end

---@param key string
---@param label string
---@param options table[] { value, label }
---@param current any
---@return table
local function select(key, label, options, current)
    for i = 1, #options do
        options[i].price = price(key, options[i].value)
    end

    return { key = key, label = label, kind = 'select', options = options, current = current }
end

---@param key string
---@param label string
---@param current boolean
---@return table
local function toggle(key, label, current)
    return { key = key, label = label, kind = 'toggle', current = current == true, price = price(key, true) }
end

---Options of one GTA mod slot, or nil when the model has none
---@param vehicle integer
---@param slot integer
---@param name string
---@return table[]?
local function modOptions(vehicle, slot, name)
    local count = GetNumVehicleMods(vehicle, slot)
    if count == 0 then return end

    local options = { { value = -1, label = locale('stock') } }

    for i = 0, count - 1 do
        local text = GetModTextLabel(vehicle, slot, i)
        text = text and GetLabelText(text)

        if not text or text == 'NULL' or text == '' then text = ('%s %d'):format(name, i + 1) end

        options[#options + 1] = { value = i, label = text }
    end

    return options
end

---@param list table[] { id, label }
---@return table[]
local function idOptions(list)
    local options = {}

    for i = 1, #list do
        options[i] = { value = list[i].id, label = list[i].label }
    end

    return options
end

---@param list table[] { label, rgb }
---@return table[]
local function rgbOptions(list)
    local options = {}

    for i = 1, #list do
        options[i] = { value = list[i].rgb, label = list[i].label }
    end

    return options
end

---@return table[]
local function paintOptions()
    local options = {}

    for _, group in ipairs(colors.paints) do
        for _, color in ipairs(group.colors) do
            options[#options + 1] = { value = color.id, label = color.label, group = group.group }
        end
    end

    return options
end

---@param vehicle integer
---@param bike boolean
---@return table[]
local function rimOptions(vehicle, bike)
    return modOptions(vehicle, bike and 24 or 23, locale('rim')) or {}
end

---@param vehicle integer
---@param props table
---@return table[]
local function build(vehicle, props)
    local bike = GetVehicleClass(vehicle) == 8
    local performance, body = {}, {}

    for _, mod in ipairs(catalog.performance) do
        local count = GetNumVehicleMods(vehicle, mod.slot)
        local levels = Config.Prices.performance[mod.key]

        if count > 0 and levels then
            local options = { { value = -1, label = locale('stock') } }

            for level = 0, math.min(count, #levels) - 1 do
                options[#options + 1] = { value = level, label = locale('level', level + 1) }
            end

            performance[#performance + 1] = select(mod.key, mod.label, options, props[mod.key])
        end
    end

    performance[#performance + 1] = toggle('modTurbo', 'Turbo', props.modTurbo)

    for _, mod in ipairs(catalog.parts) do
        local options = modOptions(vehicle, mod.slot, mod.label)
        if options then body[#body + 1] = select(mod.key, mod.label, options, props[mod.key]) end
    end

    local hornOptions = modOptions(vehicle, 14, 'Horn')
    local paints = paintOptions()
    local paint = {}

    for _, slot in ipairs(catalog.paints) do
        local current = props[slot.key]
        paint[#paint + 1] = select(slot.key, slot.label, paints, type(current) == 'number' and current or nil)
    end

    local wheels = {}

    if not bike then
        wheels[#wheels + 1] = select('wheels', locale('rim_type'), idOptions(WHEEL_TYPES), props.wheels)
    end

    local rims = rimOptions(vehicle, bike)

    if #rims > 0 then
        wheels[#wheels + 1] = select(bike and 'modBackWheels' or 'modFrontWheels', locale('rims'), rims,
            bike and props.modBackWheels or props.modFrontWheels)
    end
    wheels[#wheels + 1] = toggle('modCustomTiresF', locale('custom_tyres'), props.modCustomTiresF)
    wheels[#wheels + 1] = toggle('modSmokeEnabled', locale('tyre_smoke'), props.modSmokeEnabled)
    wheels[#wheels + 1] = select('tyreSmokeColor', locale('tyre_smoke_color'), rgbOptions(colors.tyreSmoke), props.tyreSmokeColor)

    local lights = {
        toggle('modXenon', locale('xenon'), props.modXenon),
        select('xenonColor', locale('xenon_color'), idOptions(colors.xenon), props.xenonColor),
    }

    if not bike then
        local neonOptions = {}
        for i = 1, #NEONS do neonOptions[i] = { value = NEONS[i].value, label = NEONS[i].label } end

        lights[#lights + 1] = select('neonEnabled', locale('neon'), neonOptions, props.neonEnabled)
        lights[#lights + 1] = select('neonColor', locale('neon_color'), rgbOptions(colors.neonColors), props.neonColor)
    end

    local extras = {
        select('windowTint', locale('window_tint'), idOptions(colors.windowTints), props.windowTint),
        select('plateIndex', locale('plate'), idOptions(colors.plateIndexes), props.plateIndex),
    }

    if hornOptions then extras[#extras + 1] = select('modHorns', locale('horn'), hornOptions, props.modHorns) end

    local categories = {
        { id = 'performance', label = locale('cat_performance'), icon = 'gauge', items = performance },
        { id = 'body', label = locale('cat_body'), icon = 'car', items = body },
        { id = 'paint', label = locale('cat_paint'), icon = 'paint', items = paint },
        { id = 'wheels', label = locale('cat_wheels'), icon = 'wheel', items = wheels },
        { id = 'lights', label = locale('cat_lights'), icon = 'bulb', items = lights },
        { id = 'extras', label = locale('cat_extras'), icon = 'star', items = extras },
    }

    for i = #categories, 1, -1 do
        if #categories[i].items == 0 then table.remove(categories, i) end
    end

    return categories
end

---NUI JSON numbers can arrive as floats; the server wants integers
---@param value any
---@return any
local function clean(value)
    if type(value) == 'number' then return math.tointeger(value) or value end

    if type(value) == 'table' then
        local out = {}
        for i = 1, #value do out[i] = clean(value[i]) end
        return out
    end

    return value
end

---@param restore boolean put the car back as it was (nothing bought)
local function finish(restore)
    if not session then return end

    local current = session
    session = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    camera.stop()

    if DoesEntityExist(current.vehicle) then
        if restore then lib.setVehicleProperties(current.vehicle, current.original) end
        FreezeEntityPosition(current.vehicle, false)
    end

    -- not awaited: this also runs from onResourceStop, which can't yield
    lib.callback('city_mechanic:close', false, function() end)
    TriggerEvent('city_mechanic:client:menuClosed')
end

function tuning.open()
    if session or not cache.vehicle or cache.seat ~= -1 then return end

    local vehicle = cache.vehicle
    local info = lib.callback.await('city_mechanic:open', false, NetworkGetNetworkIdFromEntity(vehicle))

    if not info then
        return exports.qbx_core:Notify(locale('error_cannot_open'), 'error')
    end

    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    FreezeEntityPosition(vehicle, true)
    SetVehicleModKit(vehicle, 0)

    local props = lib.getVehicleProperties(vehicle)

    session = { vehicle = vehicle, original = props, bike = GetVehicleClass(vehicle) == 8 }

    camera.start(vehicle)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        label = Config.Label,
        plate = props.plate,
        model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))),
        balance = info.balance,
        repair = info.repair,
        categories = build(vehicle, props),
    })
end

function tuning.active()
    return session ~= nil
end

RegisterNUICallback('ready', function(_, cb)
    cb({ theme = theme, labels = lib.getLocales() })
end)

RegisterNUICallback('preview', function(data, cb)
    if not session or type(data) ~= 'table' or type(data.key) ~= 'string' then return cb(false) end

    local key, value = data.key, clean(data.value)

    -- only what the catalog allows; the original value is always fine (going back to it)
    if catalog.price(key, value, Config.Prices) == nil then return cb(false) end

    local props = { [key] = value }

    -- ox_lib only applies custom tyres together with the rim
    if key == 'modCustomTiresF' then props.modFrontWheels = GetVehicleMod(session.vehicle, 23) end

    lib.setVehicleProperties(session.vehicle, props)

    if key == 'wheels' then
        SetVehicleMod(session.vehicle, 23, -1, false)
        return cb({ rims = rimOptions(session.vehicle, session.bike) })
    end

    cb(true)
end)

-- Properties that go back together with a key when one change is undone
local REVERT_WITH = {
    color1 = { 'paintType1', 'pearlescentColor' },
    color2 = { 'paintType2' },
    wheels = { 'modFrontWheels', 'modCustomTiresF' },
}

RegisterNUICallback('revert', function(data, cb)
    if not session or type(data) ~= 'table' then return cb(false) end

    local original = session.original

    if data.all == true then
        lib.setVehicleProperties(session.vehicle, original)
        return cb({ rims = rimOptions(session.vehicle, session.bike) })
    end

    local key = data.key
    if type(key) ~= 'string' then return cb(false) end

    local props = { [key] = original[key] }

    for _, extra in ipairs(REVERT_WITH[key] or {}) do
        props[extra] = original[extra]
    end

    -- ox_lib only applies custom tyres together with the rim
    if key == 'modCustomTiresF' then props.modFrontWheels = GetVehicleMod(session.vehicle, 23) end

    lib.setVehicleProperties(session.vehicle, props)

    cb({ rims = key == 'wheels' and rimOptions(session.vehicle, session.bike) or nil })
end)

RegisterNUICallback('camera', function(data, cb)
    if session and type(data) == 'table' then
        camera.move(tonumber(data.dx) or 0, tonumber(data.dy) or 0, tonumber(data.zoom) or 0)
    end

    cb(true)
end)

RegisterNUICallback('focus', function(data, cb)
    if session and type(data) == 'table' and type(data.category) == 'string' then camera.focus(data.category) end
    cb(true)
end)

RegisterNUICallback('buy', function(data, cb)
    if not session or type(data) ~= 'table' or type(data.cart) ~= 'table' then return cb(false) end

    local cart = {}

    for key, value in pairs(data.cart) do
        cart[key] = clean(value)
    end

    local ok, result = lib.callback.await('city_mechanic:buy', false, cart, data.repair == true)

    if not ok then
        exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
        return cb(false)
    end

    if not session then return cb(false) end

    if result.repaired then
        SetVehicleFixed(session.vehicle)
        SetVehicleDeformationFixed(session.vehicle)
        SetVehicleEngineHealth(session.vehicle, 1000.0)
    end

    session.original = lib.getVehicleProperties(session.vehicle)

    exports.qbx_core:Notify(locale('bought', result.total), 'success')
    cb({ balance = result.balance })
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    finish(true)
end)

lib.onCache('vehicle', function(vehicle)
    if session and vehicle ~= session.vehicle then finish(true) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then finish(true) end
end)

return tuning
