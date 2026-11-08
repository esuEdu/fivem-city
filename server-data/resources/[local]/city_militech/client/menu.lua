-- The tuner screen. The page only shows numbers: every slider move asks this file for the resulting handling and
-- stats (shared/tuning.lua), and Apply sends the setup to the server, which checks it and puts it on the car.
local theme = require '@city_ui.theme'
local tuning = require 'shared.tuning'
local handling = require 'client.handling'

local session

---@param settings any
---@return table<string, number>
local function clean(settings)
    return tuning.validate(settings, Config.Params) or {}
end

---The params this car has (a field the game can't read hides its slider)
---@param stock table<string, number>
---@return table[]
local function availableParams(stock)
    local list = {}

    for i = 1, #Config.Params do
        local param = Config.Params[i]
        local main = param.effects[1].field

        if stock[main] then
            list[#list + 1] = {
                id = param.id, group = param.group, label = param.label, help = param.help,
                left = param.left, right = param.right, min = param.min, max = param.max, step = param.step,
                unit = param.unit, field = main,
            }
        end
    end

    return list
end

---@param settings table<string, number>
---@return table
local function preview(settings)
    local values = tuning.effective(session.stock, settings, Config.Params)
    return { values = values, stats = tuning.stats(values, session.upgrades) }
end

local function close()
    if not session then return end

    session = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    lib.callback('city_militech:close', false, function() end)
end

RegisterNetEvent('city_militech:client:open', function(netId, settings)
    if session or GetInvokingResource() then return end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or vehicle ~= cache.vehicle or cache.seat ~= -1 then return end

    local stock = handling.stock(vehicle)
    local upgrades = handling.upgrades(vehicle)

    session = { vehicle = vehicle, stock = stock, upgrades = upgrades }

    local current = clean(settings)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local name = GetLabelText(model)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        theme = theme,
        vehicle = { name = name ~= 'NULL' and name or model, plate = GetVehicleNumberPlateText(vehicle) },
        groups = Config.Groups,
        params = availableParams(stock),
        stock = { values = stock, stats = tuning.stats(stock, upgrades) },
        settings = current,
        current = preview(current),
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
    cb(preview(clean(type(data) == 'table' and data.settings)))
end)

RegisterNUICallback('apply', function(data, cb)
    if not session then return cb({ ok = false, error = 'failed' }) end

    local reset = type(data) == 'table' and data.reset == true
    local settings = reset and {} or clean(type(data) == 'table' and data.settings)

    local ok, result = lib.callback.await('city_militech:apply', false, settings)

    if not ok then
        exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
        return cb({ ok = false, error = result })
    end

    exports.qbx_core:Notify(locale(reset and 'restored' or 'applied'), 'success')
    cb({ ok = true, settings = result, current = preview(result) })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not session then return end
    SetNuiFocus(false, false)
end)
