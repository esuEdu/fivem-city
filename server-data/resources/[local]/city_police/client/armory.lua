-- The station armory panel on the screen page: the Armory tab takes gear from the unlocked tiers, the Unlocks tab (a
-- padlock) unlocks the tiers rank by rank. The server decides everything; this only shows its answers.

local job = require 'client.job'
local theme = require '@city_ui.theme'

local open = false

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'armoryOff' })
end

local function labels()
    return {
        title = locale('armory'), subtitle = locale('armory_subtitle'), stock = locale('armory_tab_stock'),
        unlocks = locale('armory_tab_unlocks'), take = locale('armory_take'), unlock = locale('armory_unlock'),
        unlocked = locale('armory_unlocked'), requires = locale('armory_requires'), previous = locale('armory_previous'),
        weapon = locale('armory_weapons'), ammo = locale('armory_ammo'), gear = locale('armory_gear'),
        rank = locale('armory_rank'), empty = locale('armory_empty'), carry = locale('armory_carry'),
        allWeapons = locale('armory_all_weapons'), next = locale('armory_next'),
    }
end

local function show()
    local data = lib.callback.await('city_police:armory:open', false)
    if not data then return job.fail('too_far') end

    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'armory', theme = theme, data = data, labels = labels() })
end

AddEventHandler('city_police:client:armory', function()
    if not job.onDuty() then return end
    show()
end)

RegisterNUICallback('armoryClose', function(_, cb)
    cb(1)
    close()
end)

---@param name string server callback
---@param arg unknown
local function ask(name, arg)
    local ok, result = lib.callback.await(name, false, arg)
    if not ok then return job.fail(result) end

    SendNUIMessage({ action = 'armoryData', data = result })
end

RegisterNUICallback('armoryUnlock', function(data, cb)
    cb(1)
    local tier = type(data) == 'table' and math.tointeger(data.tier)
    if tier then ask('city_police:armory:unlock', tier) end
end)

RegisterNUICallback('armoryTake', function(data, cb)
    cb(1)
    local name = type(data) == 'table' and data.name
    if type(name) == 'string' then ask('city_police:armory:take', name) end
end)

-- Clocking out or leaving the job closes it
AddEventHandler('QBCore:Client:OnJobUpdate', function()
    if open and not job.onDuty() then close() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    close()
end)
