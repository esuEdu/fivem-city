-- The staff tuner screen. Rows are absolute handling values (vector fields split into x/y/z rows). Stock values come
-- from city_militech, which also applies the setup when the server puts it on the car's `militechStaff` bag.
lib.locale()

local theme = require '@city_ui.theme'
local tuning = require '@city_militech.shared.tuning'
local fields = require 'shared.fields'

local session

---@param vehicle integer
---@return table
local function upgrades(vehicle)
    SetVehicleModKit(vehicle, 0)

    return {
        engine = GetVehicleMod(vehicle, 11),
        brakes = GetVehicleMod(vehicle, 12),
        transmission = GetVehicleMod(vehicle, 13),
        turbo = IsToggleModOn(vehicle, 18),
    }
end

---@param value any
---@param comp string?
---@return number?
local function component(value, comp)
    if value == nil then return end
    if not comp then return type(value) == 'number' and value or nil end

    local index = comp == 'x' and 1 or comp == 'y' and 2 or 3
    local number = type(value) == 'table' and (value[comp] or value[index]) or (type(value) ~= 'number' and value[comp])

    return type(number) == 'number' and number or nil
end

---Page rows → a setup for the server: scalars as numbers, vectors as { x, y, z } with stock for untouched parts
---@param rows any
---@return table
local function toSetup(rows)
    local setup = {}
    if type(rows) ~= 'table' then return setup end

    for i = 1, #fields.list do
        local def = fields.list[i]
        local value = rows[fields.rowId(def)]

        if type(value) == 'number' then
            if def.comp then
                local stock = session.stock[def.field]
                local vector = setup[def.field] or {
                    x = component(stock, 'x') or 0.0,
                    y = component(stock, 'y') or 0.0,
                    z = component(stock, 'z') or 0.0,
                }

                vector[def.comp] = value
                setup[def.field] = vector
            else
                setup[def.field] = value
            end
        end
    end

    return setup
end

---A setup → page rows
---@param setup table
---@return table<string, number>
local function toRows(setup)
    local rows = {}

    for i = 1, #fields.list do
        local def = fields.list[i]
        local value = component(setup[def.field], def.comp)

        if value then rows[fields.rowId(def)] = value end
    end

    return rows
end

---@param setup table
---@return table
local function stats(setup)
    local values = {}

    for field, value in pairs(session.stock) do
        if type(value) == 'number' then values[field] = value end
    end

    for field, value in pairs(setup) do
        if type(value) == 'number' then values[field] = value end
    end

    return tuning.stats(values, session.upgrades)
end

local function close()
    if not session then return end

    session = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    lib.callback('city_militech_staff:close', false, function() end)
end

RegisterNetEvent('city_militech_staff:client:open', function(netId, setup)
    if session or GetInvokingResource() then return end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or vehicle ~= cache.vehicle or cache.seat ~= -1 then return end

    local stock = exports.city_militech:Stock(vehicle, fields.names())
    session = { vehicle = vehicle, stock = stock, upgrades = upgrades(vehicle) }

    local rows = {}

    for i = 1, #fields.list do
        local def = fields.list[i]
        local value = component(stock[def.field], def.comp)

        if value then
            rows[#rows + 1] = {
                id = fields.rowId(def), field = def.field, group = def.group, label = def.label, help = def.help,
                min = def.min, max = def.max, soft = def.soft, step = def.step, unit = def.unit, int = def.int == true,
                stock = value,
            }
        end
    end

    local current = type(setup) == 'table' and setup or {}
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local name = GetLabelText(model)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        theme = theme,
        vehicle = { name = name ~= 'NULL' and name or model, plate = GetVehicleNumberPlateText(vehicle) },
        groups = Config.Groups,
        rows = rows,
        values = toRows(current),
        stockStats = stats({}),
        stats = stats(current),
    })

    -- leaving the car closes the tuner
    CreateThread(function()
        while session and session.vehicle == vehicle do
            if cache.vehicle ~= vehicle or cache.seat ~= -1 then close() end
            Wait(250)
        end
    end)
end)

RegisterNUICallback('preview', function(data, cb)
    if not session then return cb(false) end
    cb({ stats = stats(toSetup(type(data) == 'table' and data.values)) })
end)

RegisterNUICallback('apply', function(data, cb)
    if not session then return cb({ ok = false, error = 'failed' }) end

    local reset = type(data) == 'table' and data.reset == true
    local setup = reset and {} or toSetup(type(data) == 'table' and data.values)

    local ok, result = lib.callback.await('city_militech_staff:apply', false, setup)

    if not ok then
        exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
        return cb({ ok = false, error = result })
    end

    exports.qbx_core:Notify(locale(reset and 'restored' or 'applied'), 'success')
    cb({ ok = true, values = toRows(result), stats = stats(result) })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not session then return end
    SetNuiFocus(false, false)
end)
