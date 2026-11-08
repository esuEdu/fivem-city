-- Adds Wallet to city_phone: the player's bank on the phone (balance and statement, Pix, cards) and approving card
-- purchases over the limit. Every request goes to city_bank's app callbacks, which apply the bank's own rules.
local APP = 'wallet'

-- What the page may ask city_bank (city_bank:app:<name>); the server checks everything again
local ALLOWED = {
    accounts = true, history = true, lookup = true, send = true, cards = true,
    blockCard = true, cardLimits = true, cardContactless = true, approve = true,
}

local pendingApproval

local TEXTS = {
    en = { title = 'Approve purchase?', text = '$%s at %s · card %s' },
    ['pt-br'] = { title = 'Aprovar compra?', text = '$%s em %s · cartão %s' },
}

local function t(key)
    local settings = exports.city_phone:GetSettings() or {}
    return (TEXTS[settings.language] or TEXTS.en)[key]
end

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Wallet',
        labels = { ['pt-br'] = 'Carteira' },
        icon = 'web/icon.svg',
        color = 'linear-gradient(180deg, #1c1c1e, #000000)',
        page = 'web/index.html',
        dock = true,
        order = 3,
    })
end

CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

RegisterNUICallback('bank', function(data, cb)
    local name = type(data) == 'table' and data.name

    if not ALLOWED[name] then return cb({ ok = false, error = 'bad_request' }) end

    local args = type(data.args) == 'table' and data.args or {}
    local reply = lib.callback.await(('city_bank:app:%s'):format(name), false, table.unpack(args, 1, 6))

    if name == 'approve' then pendingApproval = nil end

    cb(type(reply) == 'table' and reply or { ok = false, error = 'failed' })
end)

-- The page asks on load whether a purchase is waiting for an answer
RegisterNUICallback('pending', function(_, cb)
    if pendingApproval and GetGameTimer() > pendingApproval.expires then pendingApproval = nil end
    if pendingApproval then pendingApproval.seconds = math.ceil((pendingApproval.expires - GetGameTimer()) / 1000) end
    cb({ ok = true, result = pendingApproval })
end)

-- A purchase over one of my cards' limits: the phone opens on the question (just a notification in Do Not Disturb)
RegisterNetEvent('city_bank:client:approvalRequest', function(request)
    if GetInvokingResource() or type(request) ~= 'table' then return end

    request.expires = GetGameTimer() + (tonumber(request.seconds) or 60) * 1000
    pendingApproval = request

    exports.city_phone:Notify({
        app = 'wallet', title = t('title'), force = true,
        text = t('text'):format(request.amount, request.merchant or '?', request.last4 or '????'),
    })

    exports.city_phone:SendAppMessage(APP, { action = 'approval', request = request })

    local settings = exports.city_phone:GetSettings() or {}

    if not settings.dnd then
        exports.city_phone:OpenApp(APP)
        if not exports.city_phone:IsOpen() then exports.city_phone:Open() end
    end
end)
