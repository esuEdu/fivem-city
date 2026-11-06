-- Card machine. Merchant: uses the item, types the amount and picks a nearby customer.
-- Customer: gets the machine on screen with the amount and pays by inserting (PIN) or tapping a card.
local nui = require 'client.nui'

lib.locale()

RegisterNetEvent('city_bank:client:posMerchant', function(slot)
    if nui.view then return end

    local nearby = lib.getNearbyPlayers(GetEntityCoords(cache.ped), Config.PosRange, false)

    if #nearby == 0 then return lib.notify({ type = 'error', description = locale('error_no_player') }) end

    local options = {}

    for i = 1, #nearby do
        local id = GetPlayerServerId(nearby[i].id)
        options[i] = { value = id, label = locale('pos_customer', id) }
    end

    local input = lib.inputDialog(locale('pos_title'), {
        { type = 'number', label = locale('pos_amount'), required = true, min = 1, max = 100000 },
        { type = 'select', label = locale('pos_customer_label'), options = options, required = true, default = options[1].value },
    })

    if not input then return end

    local reply = lib.callback.await('city_bank:posCharge', false, slot, input[2], math.floor(tonumber(input[1]) or 0))

    if not reply or not reply.ok then
        return lib.notify({ type = 'error', description = locale('error_' .. (reply and reply.error or 'failed')) })
    end

    lib.notify({ type = 'inform', description = locale('notify_pos_waiting') })
end)

RegisterNetEvent('city_bank:client:posRequest', function(charge)
    if type(charge) ~= 'table' or type(charge.id) ~= 'string' then return end

    -- Busy with another screen: decline instead of opening on top of it
    if nui.view then return lib.callback.await('city_bank:posDecline', false, charge.id) end

    local data = lib.callback.await('city_bank:posCards', false, charge.id)

    if not data or not data.ok then return end

    nui.charge = charge.id
    nui.open('pos', { charge = charge, cards = data.cards })
end)

RegisterNUICallback('posPay', function(data, cb)
    if nui.view ~= 'pos' or type(data) ~= 'table' then return cb({ ok = false }) end

    local reply = lib.callback.await('city_bank:posPay', false, nui.charge, data.slot, data.method, data.mode, data.pin)

    if reply and reply.ok then nui.charge = nil end

    cb(reply or { ok = false })
end)
