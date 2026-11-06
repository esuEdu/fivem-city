-- ATM props (ox_target) and the ATM / cash desk screen. The server checks the player is still at the ATM or branch.
local nui = require 'client.nui'

lib.locale()

local atmCoords

---@return 'atm' | 'teller'
local function mode()
    return nui.branch and 'teller' or 'atm'
end

local function openAtm(entity)
    if nui.view then return end

    atmCoords = GetEntityCoords(entity)

    local data = lib.callback.await('city_bank:atmCards', false)

    if not data or not data.ok then return end
    if #data.cards == 0 then return lib.notify({ type = 'error', description = locale('error_no_card') }) end

    nui.open('atm', { cards = data.cards, teller = false })
end

exports.ox_target:addModel(Config.AtmModels, {
    {
        name = 'city_bank:atm',
        icon = 'fa-solid fa-money-bill-wave',
        label = locale('target_atm'),
        distance = 1.5,
        onSelect = function(data) openAtm(data.entity) end,
    },
})

RegisterNUICallback('atmAuth', function(data, cb)
    if nui.view ~= 'atm' or type(data) ~= 'table' then return cb({ ok = false }) end

    cb(lib.callback.await('city_bank:atmAuth', false, data.slot, data.pin, mode(), mode() == 'atm' and atmCoords or nil) or { ok = false })
end)

RegisterNUICallback('atmPeek', function(_, cb)
    if nui.view ~= 'atm' then return cb({ ok = false }) end

    cb(lib.callback.await('city_bank:atmPeek', false) or { ok = false })
end)

RegisterNUICallback('atmMove', function(data, cb)
    if nui.view ~= 'atm' or type(data) ~= 'table' then return cb({ ok = false }) end

    local name = data.kind == 'deposit' and 'city_bank:atmDeposit' or 'city_bank:atmWithdraw'

    cb(lib.callback.await(name, false, data.amount) or { ok = false })
end)

---Back from the cash desk to the branch panel
RegisterNUICallback('tellerBack', function(_, cb)
    if nui.view == 'atm' and nui.branch then
        lib.callback.await('city_bank:atmClose', false)
        nui.view = 'bank'
    end

    cb(1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeModel(Config.AtmModels, 'city_bank:atm')
end)
