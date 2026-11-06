local theme = require '@city_ui.theme'
local nui = require 'client.nui'

lib.locale()

local peds = {}
local blips = {}


-- Panel requests the page may forward to the server (the server checks everything again)
local PANEL_CALLS = {
    dashboard = true, accounts = true, createSavings = true, createShared = true, requestJoin = true, members = true,
    decideMember = true, setMember = true, removeMember = true, addViewer = true, leaveShared = true, move = true,
    setGoal = true, rename = true, lookup = true, send = true, scheduled = true, schedule = true, scheduleState = true,
    cards = true, issueCard = true, blockCard = true, unlockCard = true, cardPin = true, cardLimits = true,
    cardContactless = true, bills = true, payBill = true, loans = true, requestLoan = true, payInstallment = true,
    history = true, staffQueue = true, staffDecide = true, staffClient = true, staffCeilings = true, staffFreeze = true,
    staffBankers = true, staffSetBanker = true,
}

local function setupNui()
    SendNUIMessage({ action = 'setup', theme = theme, labels = lib.getLocales(), currency = '$' })
end

---Closes the panel if the player walks away from the banker
local function watchDistance(branch)
    CreateThread(function()
        while nui.branch do
            if #(GetEntityCoords(cache.ped) - branch.coords.xyz) > Config.MaxDistance + 1.0 then
                nui.close()
                break
            end

            Wait(500)
        end
    end)
end

---@param branchId integer
local function openBank(branchId)
    if nui.view then return end

    local data = lib.callback.await('city_bank:open', false, branchId)

    if not data or not data.ok then
        return lib.notify({ type = 'error', description = locale(data and data.error == 'far' and 'error_far' or 'error_unavailable') })
    end

    nui.open('bank', { branch = Config.Branches[branchId].label, data = data })
    nui.branch = branchId
    watchDistance(Config.Branches[branchId])
end

---@param branchId integer
local function spawnBanker(branchId)
    local branch = Config.Branches[branchId]

    lib.requestModel(branch.model)

    local ped = CreatePed(0, branch.model, branch.coords.x, branch.coords.y, branch.coords.z - 1.0, branch.coords.w, false, false)

    SetModelAsNoLongerNeeded(branch.model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'city_bank:open',
            icon = 'fa-solid fa-building-columns',
            label = locale('target_open'),
            distance = 2.0,
            onSelect = function() openBank(branchId) end,
        },
    })

    peds[branchId] = ped
end

---@param branchId integer
local function removeBanker(branchId)
    local ped = peds[branchId]

    if not ped then return end

    exports.ox_target:removeLocalEntity(ped, 'city_bank:open')
    DeleteEntity(ped)
    peds[branchId] = nil
end

for branchId, branch in ipairs(Config.Branches) do
    lib.points.new({
        coords = branch.coords.xyz,
        distance = Config.PedDistance,
        onEnter = function() spawnBanker(branchId) end,
        onExit = function() removeBanker(branchId) end,
    })

    local blip = AddBlipForCoord(branch.coords.x, branch.coords.y, branch.coords.z)

    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip_name'))
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

RegisterNUICallback('ready', function(_, cb)
    setupNui()
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    nui.close()
    cb(1)
end)

RegisterNUICallback('registerFingerprint', function(_, cb)
    if nui.view ~= 'bank' then return cb({ ok = false }) end

    cb(lib.callback.await('city_bank:registerFingerprint', false) or { ok = false })
end)

---Generic panel request: { name, args }
RegisterNUICallback('call', function(data, cb)
    if nui.view ~= 'bank' or type(data) ~= 'table' or not PANEL_CALLS[data.name] then return cb({ ok = false, error = 'bad_request' }) end

    local args = type(data.args) == 'table' and data.args or {}

    cb(lib.callback.await(('city_bank:%s'):format(data.name), false, table.unpack(args, 1, 8)) or { ok = false, error = 'failed' })
end)

---The branch cash desk: same screen as an ATM, without the ATM's per-operation cap
RegisterNUICallback('openTeller', function(_, cb)
    if nui.view ~= 'bank' or not nui.branch then return cb({ ok = false }) end

    nui.view = 'atm'
    cb(lib.callback.await('city_bank:atmCards', false) or { ok = false })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    nui.close()

    for branchId in pairs(peds) do removeBanker(branchId) end
    for i = 1, #blips do RemoveBlip(blips[i]) end
end)

