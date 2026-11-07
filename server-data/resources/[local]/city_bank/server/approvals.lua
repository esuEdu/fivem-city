-- A card purchase over the card's limit asks its holder on their phone (BANCO_DESIGN.md 4.1): "Purchase of $X at
-- [merchant], approve?". The holder has settings.app.approvalSeconds; offline, no phone, declined or no answer means
-- no. Only the holder can answer, from their own phone (the app answers as whoever uses it).
local access = require 'server.access'
local settings = require 'server.config'

local approvals = {}

---@type table<string, { holder: string, resolve: fun(accept: boolean, why?: string): table? }>
local pending = {}

---@param holder string the card holder's citizenid
---@param info { amount: integer, merchant: string, last4: string }
---@param resolve fun(accept: boolean, why?: string): table? runs once with the answer
---@return boolean sent false when the holder can't be asked (offline or no phone)
function approvals.request(holder, info, resolve)
    local player = exports.qbx_core:GetPlayerByCitizenId(holder)
    local src = player and player.PlayerData.source

    if not src or not access.onPhone(src) then return false end

    local id = lib.string.random('............')
    local seconds = settings.app.approvalSeconds

    pending[id] = { holder = holder, resolve = resolve }

    TriggerClientEvent('city_bank:client:approvalRequest', src, {
        id = id, amount = info.amount, merchant = info.merchant, last4 = info.last4, seconds = seconds,
    })

    SetTimeout(seconds * 1000, function()
        local request = pending[id]
        if not request then return end

        pending[id] = nil
        request.resolve(false, 'timeout')
    end)

    return true
end

lib.callback.register('city_bank:app:approve', function(source, id, accept)
    local src = source

    if access.throttled(src, 'app:approve') then return { ok = false, error = 'busy' } end

    local request = type(id) == 'string' and pending[id]
    local player = access.onPhone(src)

    if not request or not player or player.PlayerData.citizenid ~= request.holder then return { ok = false, error = 'expired' } end

    pending[id] = nil

    return request.resolve(accept == true) or { ok = true }
end)

return approvals
