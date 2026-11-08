local theme = require '@city_ui.theme'
local testDrive = require 'client.testdrive'

local catalog
local isOpen = false
local zones = {}
local blip

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@return table
local function balances()
    local playerData = exports.qbx_core:GetPlayerData()
    local money = playerData and playerData.money or {}

    return { cash = money.cash or 0, bank = money.bank or 0 }
end

local function open()
    if isOpen or cache.vehicle then return end

    catalog = catalog or lib.callback.await('city_dealership:catalog', false)
    if not catalog then return end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        label = Config.Label,
        categories = Config.Categories,
        vehicles = catalog,
        finance = {
            minDownPct = Config.Finance.minDownPct,
            installments = Config.Finance.installments,
            interestPct = Config.Finance.interestPct,
            everyHours = Config.Finance.everyHours,
            repoAfter = Config.Finance.repoAfter,
        },
        testDriveSeconds = Config.TestDrive.seconds,
        balances = balances(),
        finances = lib.callback.await('city_dealership:finances', false) or {},
    })
end

---Performance bars from the model's handling, 0-100, without spawning the car
---@param model string
---@return table
local function stats(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return {} end

    local function pct(value, max)
        return math.floor(math.max(0, math.min(1, value / max)) * 100 + 0.5)
    end

    local speed = GetVehicleModelEstimatedMaxSpeed(hash)

    return {
        topSpeed = math.floor(speed * 3.6 + 0.5),
        speed = pct(speed, 55.0),
        acceleration = pct(GetVehicleModelAcceleration(hash), 0.45),
        braking = pct(GetVehicleModelMaxBraking(hash), 1.6),
        traction = pct(GetVehicleModelMaxTraction(hash), 3.2),
        seats = GetVehicleModelNumberOfSeats(hash),
    }
end

RegisterNUICallback('ready', function(_, cb)
    local labels = {}

    for _, key in ipairs({
        'ui_kicker', 'ui_search', 'ui_all', 'ui_sort_price_asc', 'ui_sort_price_desc', 'ui_sort_name', 'ui_count',
        'ui_empty', 'ui_select', 'ui_close', 'ui_catalog', 'ui_my_finance', 'ui_brand', 'ui_category', 'ui_seats',
        'ui_top_speed', 'ui_speed', 'ui_acceleration', 'ui_braking', 'ui_traction', 'ui_price', 'ui_test_drive',
        'ui_test_drive_hint', 'ui_pay_full', 'ui_finance', 'ui_cash', 'ui_bank', 'ui_balance', 'ui_down', 'ui_installments',
        'ui_installment_of', 'ui_interest', 'ui_total', 'ui_every', 'ui_buy', 'ui_confirm', 'ui_cancel', 'ui_bought',
        'ui_finance_empty', 'ui_plate', 'ui_paid', 'ui_left', 'ui_next', 'ui_overdue', 'ui_pay_off', 'ui_pay_off_hint',
        'ui_garage_hint', 'ui_finance_note', 'ui_now',
    }) do
        labels[key] = locale(key)
    end

    cb({ theme = theme, labels = labels })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(true)
end)

RegisterNUICallback('stats', function(data, cb)
    cb(type(data) == 'table' and type(data.model) == 'string' and stats(data.model) or {})
end)

RegisterNUICallback('buy', function(data, cb)
    if type(data) ~= 'table' then return cb(false) end

    local plate, err = lib.callback.await('city_dealership:buy', false, {
        model = data.model,
        account = data.account,
        financed = data.financed == true,
        downPct = math.tointeger(tonumber(data.downPct)),
        count = math.tointeger(tonumber(data.count)),
    })

    if not plate then
        exports.qbx_core:Notify(locale(('error_%s'):format(err or 'failed')), 'error')
        return cb(false)
    end

    exports.qbx_core:Notify(locale('bought', plate), 'success')
    cb({
        plate = plate,
        balances = balances(),
        finances = lib.callback.await('city_dealership:finances', false) or {},
    })
end)

RegisterNUICallback('payOff', function(data, cb)
    local ok, err = lib.callback.await('city_dealership:payOff', false, type(data) == 'table' and data.id)

    if not ok then
        exports.qbx_core:Notify(locale(('error_%s'):format(err or 'failed')), 'error')
        return cb(false)
    end

    exports.qbx_core:Notify(locale('paid_off'), 'success')
    cb({ balances = balances(), finances = lib.callback.await('city_dealership:finances', false) or {} })
end)

RegisterNUICallback('testDrive', function(data, cb)
    local model = type(data) == 'table' and data.model
    if type(model) ~= 'string' then return cb(false) end

    close()
    cb(true)

    testDrive.start(model)
end)

local function addBlip()
    local coords = Config.Blip.coords

    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Label)
    EndTextCommandSetBlipName(blip)
end

local function addComputers()
    for i = 1, #Config.Computers do
        local computer = Config.Computers[i]

        zones[i] = exports.ox_target:addBoxZone({
            coords = computer.coords,
            size = computer.size,
            rotation = computer.rotation,
            options = {
                {
                    name = ('city_dealership:computer:%d'):format(i),
                    label = locale('target_computer'),
                    icon = 'fas fa-desktop',
                    distance = Config.UseDistance,
                    canInteract = function()
                        return not cache.vehicle and not testDrive.active()
                    end,
                    onSelect = function()
                        CreateThread(open)
                    end,
                },
            },
        })
    end
end

addBlip()
addComputers()

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    close()

    for i = 1, #zones do
        exports.ox_target:removeZone(zones[i])
    end

    if blip then RemoveBlip(blip) end
end)
