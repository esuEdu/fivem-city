lib.locale()

local tuning = require 'client.tuning'

local targets = {}
local zones = {}
local blip
local inBay, inGarage = false, false
-- Staff may use the tuning bay without the job (Config.StaffAce); asked once from the server, which checks again
local staffTuner = false
local prompt
local refresh

---@return boolean
local function onDuty()
    local playerData = exports.qbx_core:GetPlayerData()
    local job = playerData and playerData.job

    return job ~= nil and job.name == Config.Job and job.onduty == true
end

---@return boolean
local function isMechanic()
    local playerData = exports.qbx_core:GetPlayerData()
    local job = playerData and playerData.job

    return job ~= nil and job.name == Config.Job
end

---What the tune key does right now, if anything
---@return string?
local function action()
    if not cache.vehicle or cache.seat ~= -1 or tuning.active() then return end
    if inBay and (onDuty() or staffTuner) then return 'tune' end
    if inGarage and onDuty() and Entity(cache.vehicle).state.mechanicWork then return 'store' end
end

local keybind = lib.addKeybind({
    name = 'city_mechanic_use',
    description = 'Mechanic: tune / put away work vehicle',
    defaultKey = Config.TuneKey,
    disabled = true,
    onPressed = function()
        local current = action()

        if current == 'tune' then
            lib.hideTextUI()
            prompt = nil
            tuning.open()
            refresh()
        elseif current == 'store' then
            if lib.callback.await('city_mechanic:storeVehicle', false) then lib.hideTextUI() end
        end
    end,
})

refresh = function()
    local current = action()

    keybind:disable(current == nil)

    if current == prompt then return end

    prompt = current

    if current then
        lib.showTextUI(locale(('prompt_%s'):format(current), Config.TuneKey), { icon = 'fa-solid fa-wrench', position = 'left-center' })
    else
        lib.hideTextUI()
    end
end

local function openGarage()
    local options = {}

    for i, vehicle in ipairs(Config.Garage.vehicles) do
        options[#options + 1] = {
            title = vehicle.label,
            icon = 'car',
            onSelect = function()
                local ok, err = lib.callback.await('city_mechanic:takeVehicle', false, i)
                if not ok then exports.qbx_core:Notify(locale(('error_%s'):format(err or 'failed')), 'error') end
            end,
        }
    end

    lib.registerContext({ id = 'city_mechanic_garage', title = locale('garage'), options = options })
    lib.showContext('city_mechanic_garage')
end

local function addTargets()
    targets[#targets + 1] = exports.ox_target:addSphereZone({
        coords = Config.Duty,
        radius = 1.2,
        options = {
            {
                name = 'city_mechanic:duty',
                label = locale('target_duty'),
                icon = 'fas fa-clipboard-user',
                distance = Config.UseDistance,
                canInteract = isMechanic,
                onSelect = function()
                    local state = lib.callback.await('city_mechanic:duty', false)
                    if state ~= nil then exports.qbx_core:Notify(locale(state and 'on_duty' or 'off_duty'), 'inform') end
                end,
            },
        },
    })

    targets[#targets + 1] = exports.ox_target:addSphereZone({
        coords = Config.Stash.coords,
        radius = 1.2,
        options = {
            {
                name = 'city_mechanic:stash',
                label = locale('target_stash'),
                icon = 'fas fa-box-open',
                distance = Config.UseDistance,
                canInteract = isMechanic,
                onSelect = function() exports.city_inventory:openInventory('stash', Config.Stash.id) end,
            },
        },
    })

    targets[#targets + 1] = exports.ox_target:addBoxZone({
        coords = Config.Garage.coords,
        size = Config.Garage.size,
        rotation = Config.Garage.rotation,
        options = {
            {
                name = 'city_mechanic:garage',
                label = locale('target_garage'),
                icon = 'fas fa-truck-pickup',
                distance = 6.0,
                canInteract = function() return not cache.vehicle and onDuty() end,
                onSelect = openGarage,
            },
        },
    })
end

local function addZones()
    zones[#zones + 1] = lib.zones.poly({
        points = Config.Bay.points,
        thickness = Config.Bay.thickness,
        onEnter = function()
            inBay = true
            refresh()

            if Config.StaffAce and not onDuty() then
                CreateThread(function()
                    staffTuner = lib.callback.await('city_mechanic:canTune', false) == true
                    refresh()
                end)
            end
        end,
        onExit = function()
            inBay = false
            refresh()
        end,
    })

    zones[#zones + 1] = lib.zones.box({
        coords = Config.Garage.coords,
        size = Config.Garage.size,
        rotation = Config.Garage.rotation,
        onEnter = function()
            inGarage = true
            refresh()
        end,
        onExit = function()
            inGarage = false
            refresh()
        end,
    })
end

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

lib.onCache('vehicle', function()
    -- cache updates after this handler runs
    SetTimeout(0, refresh)
end)

lib.onCache('seat', function()
    SetTimeout(0, refresh)
end)

-- PlayerData catches up a moment after these events
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(250, refresh) end)
RegisterNetEvent('QBCore:Client:SetDuty', function() SetTimeout(250, refresh) end)

-- the menu closing makes the prompt come back while still in the bay
AddEventHandler('city_mechanic:client:menuClosed', refresh)

addBlip()
addTargets()
addZones()

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for i = 1, #targets do exports.ox_target:removeZone(targets[i]) end
    for i = 1, #zones do zones[i]:remove() end
    if blip then RemoveBlip(blip) end
    if prompt then lib.hideTextUI() end
end)
