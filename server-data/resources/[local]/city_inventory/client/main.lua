local Items = require 'shared.items'
local search = require 'shared.search'

-- Read-only copy of the player's inventory; the server sends every change
---@type table<integer, InventoryItem>
local items = {}
local weight = 0
local isOpen = false
local isUsing = false

---@param value unknown
---@return integer?
local function toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---@param slot integer
---@param item? InventoryItem
---@return table entry for the UI
local function toNui(slot, item)
    if not item then
        return { slot = slot, item = false }
    end

    local definition = Items[item.name]

    return {
        slot = slot,
        item = {
            name = item.name,
            count = item.count,
            metadata = item.metadata,
            label = definition.label,
            description = definition.description,
            image = definition.image,
            weight = definition.weight * item.count,
        },
    }
end

local function setupNui()
    local entries = {}

    for slot, item in pairs(items) do
        entries[#entries + 1] = toNui(slot, item)
    end

    SendNUIMessage({
        action = 'setup',
        slots = Config.Slots,
        hotbar = Config.HotbarSlots,
        maxWeight = Config.MaxWeight,
        weight = weight,
        openKey = Config.OpenKey,
        items = entries,
        labels = {
            title = locale('ui_title'),
            use = locale('ui_use'),
        },
    })
end

---@return boolean
local function canAct()
    return LocalPlayer.state.isLoggedIn
        and not LocalPlayer.state.invBusy
        and not IsPedDeadOrDying(cache.ped, true)
        and not IsPedCuffed(cache.ped)
        and not lib.progressActive()
        and not IsPauseMenuActive()
end

---@param reason? string
local function notifyFailure(reason)
    local key = ('error_%s'):format(reason)
    local message = locale(key)

    lib.notify({
        description = message ~= key and message or locale('error_generic'),
        type = 'error',
    })
end

local function open()
    if isOpen or not canAct() then return end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param slot integer
local function useSlot(slot)
    if isUsing or not items[slot] or not canAct() then return end

    isUsing = true
    local success, result = lib.callback.await('city_inventory:use', false, slot)
    isUsing = false

    if not success then
        if result ~= 'not_used' then notifyFailure(result) end
    elseif result and isOpen then
        close()
    end
end

RegisterNetEvent('city_inventory:client:setInventory', function(newItems, newWeight)
    items = newItems
    weight = newWeight
    setupNui()
end)

RegisterNetEvent('city_inventory:client:updateSlots', function(changes, newWeight)
    local entries = {}

    for slot, item in pairs(changes) do
        items[slot] = item or nil
        entries[#entries + 1] = toNui(slot, item or nil)
    end

    weight = newWeight

    SendNUIMessage({ action = 'update', changes = entries, weight = weight })
end)

RegisterNetEvent('city_inventory:client:heal', function(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    SetEntityHealth(cache.ped, math.min(GetEntityMaxHealth(cache.ped), GetEntityHealth(cache.ped) + math.floor(amount)))
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    close()
    items = {}
    weight = 0
    setupNui()
end)

-- The page may load after the inventory arrived (e.g. when the resource restarts)
RegisterNUICallback('ready', function(_, cb)
    setupNui()
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('move', function(data, cb)
    local success = lib.callback.await('city_inventory:move', false, toInteger(data.from), toInteger(data.to), toInteger(data.count))
    cb(success == true)
end)

RegisterNUICallback('use', function(data, cb)
    cb(1)

    local slot = toInteger(data.slot)
    if slot then useSlot(slot) end
end)

lib.addKeybind({
    name = 'inventory',
    description = locale('keybind_open'),
    defaultKey = Config.OpenKey,
    onPressed = open,
})

for slot = 1, Config.HotbarSlots do
    lib.addKeybind({
        name = ('hotbar%d'):format(slot),
        description = locale('keybind_hotbar', slot),
        defaultKey = tostring(slot),
        onPressed = function()
            if isOpen then return end

            SendNUIMessage({ action = 'hotbar', slot = slot })
            useSlot(slot)
        end,
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and isOpen then
        SetNuiFocus(false, false)
    end
end)

-- Same names and arguments as ox_inventory's client exports

exports('Items', function(name)
    if name then
        return Items[name]
    end

    return Items
end)

exports('GetItemCount', function(name, metadata, strict)
    return search.count(items, name, metadata, strict)
end)

exports('Search', function(kind, names, metadata)
    if kind ~= 'count' and kind ~= 'slots' then return end

    return search.run(items, kind, names, metadata, function(slot)
        local item = items[slot]

        return { slot = slot, name = item.name, count = item.count, metadata = item.metadata, label = Items[item.name].label }
    end)
end)

exports('GetPlayerWeight', function()
    return weight
end)
