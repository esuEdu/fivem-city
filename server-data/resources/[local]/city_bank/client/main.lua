local theme = require '@city_ui.theme'

lib.locale()

local peds = {}
local blips = {}
local openBranch

local function setupNui()
    SendNUIMessage({
        action = 'setup',
        theme = theme,
        labels = lib.getLocales(),
        currency = '$',
    })
end

local function close()
    if not openBranch then return end

    openBranch = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(250)
end

---Closes the panel if the player walks away from the banker
local function watchDistance(branch)
    CreateThread(function()
        while openBranch do
            if #(GetEntityCoords(cache.ped) - branch.coords.xyz) > Config.MaxDistance + 1.0 then
                close()
                break
            end

            Wait(500)
        end
    end)
end

---@param branchId integer
local function openBank(branchId)
    if openBranch then return end

    local data = lib.callback.await('city_bank:open', false, branchId)

    if not data or not data.ok then
        return lib.notify({ type = 'error', description = locale(data and data.error == 'far' and 'error_far' or 'error_unavailable') })
    end

    openBranch = branchId
    TriggerScreenblurFadeIn(250)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', branch = Config.Branches[branchId].label, data = data })
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
    close()
    cb(1)
end)

RegisterNUICallback('registerFingerprint', function(_, cb)
    if not openBranch then return cb({ ok = false }) end

    cb(lib.callback.await('city_bank:registerFingerprint', false, openBranch) or { ok = false })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    close()

    for branchId in pairs(peds) do removeBanker(branchId) end
    for i = 1, #blips do RemoveBlip(blips[i]) end
end)
