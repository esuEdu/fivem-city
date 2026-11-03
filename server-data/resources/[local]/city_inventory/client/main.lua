local Items = require 'shared.items'
local search = require 'shared.search'
local weapons = require 'client.weapons'
local use = require 'client.use'
local compat = require 'client.compat'
local theme = require '@city_ui.theme'

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
            weapon = definition.weapon or false,
            category = definition.category,
            clip = definition.clip,
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
            equip = locale('ui_equip'),
            ammo = locale('ui_ammo'),
            hotbar = locale('ui_hotbar'),
            hotbarHint = locale('ui_hotbar_hint'),
            slots = locale('ui_slots'),
            all = locale('ui_all'),
            search = locale('ui_search'),
            qty = locale('ui_qty'),
        },
        equipped = weapons.getSerial() or false,
        metadataLabels = compat.metadataLabels(),
        categories = Config.Categories,
        theme = theme,
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
    -- Lets qbx_hud hide itself (ox_inventory:openedInventory)
    TriggerServerEvent('city_inventory:server:setOpen', true)
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('city_inventory:server:setOpen', false)
end

---Uses the item in `slot`; weapons are equipped or put away instead.
---@param slot integer
local function useSlot(slot)
    local item = items[slot]
    if isUsing or not item or not canAct() then return end

    local definition = Items[item.name]

    if use.fireEvent(slot, item) then
        if definition.close and isOpen then close() end
        return
    end

    isUsing = true

    local success, result

    if definition.weapon then
        success, result = weapons.toggle(slot)
    else
        -- The progress bar plays in the world, not behind the inventory
        if definition.client and definition.client.usetime and isOpen then close() end

        if use.progress(item) then
            success, result = lib.callback.await('city_inventory:use', false, slot, item.name)
            if success then use.finish(item) end
        else
            success, result = false, 'not_used'
        end
    end

    isUsing = false

    if not success then
        if result ~= 'not_used' then notifyFailure(result) end
    elseif result and isOpen then
        close()
    end
end

---@param slots table<integer, InventoryItem | false>
---@return table<string, integer> counts of the items in `slots` (and what they replace), before the change
local function countsBefore(slots)
    local names = {}

    for slot, item in pairs(slots) do
        if item then names[item.name] = true end
        if items[slot] then names[items[slot].name] = true end
    end

    return compat.counts(names)
end

RegisterNetEvent('city_inventory:client:setInventory', function(newItems, newWeight)
    local before = countsBefore(newItems)

    for slot in pairs(items) do
        if not newItems[slot] then newItems[slot] = false end
    end

    items = {}

    for slot, item in pairs(newItems) do
        items[slot] = item or nil
    end

    weight = newWeight
    setupNui()
    compat.changed(before, newItems)
end)

RegisterNetEvent('city_inventory:client:updateSlots', function(changes, newWeight)
    local before = countsBefore(changes)
    local entries = {}

    for slot, item in pairs(changes) do
        items[slot] = item or nil
        entries[#entries + 1] = toNui(slot, item or nil)
    end

    weight = newWeight

    SendNUIMessage({ action = 'update', changes = entries, weight = weight })
    compat.changed(before, changes)
end)

RegisterNetEvent('city_inventory:client:heal', function(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    SetEntityHealth(cache.ped, math.min(GetEntityMaxHealth(cache.ped), GetEntityHealth(cache.ped) + math.floor(amount)))
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    close()
    weapons.disarm()

    local cleared = {}

    for slot in pairs(items) do
        cleared[slot] = false
    end

    local before = countsBefore(cleared)

    items = {}
    weight = 0
    setupNui()
    compat.changed(before, cleared)
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

compat.init(function() return items end, open, close)

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

lib.addKeybind({
    name = 'reload',
    description = locale('keybind_reload'),
    defaultKey = 'R',
    onPressed = function()
        if canAct() then weapons.reload() end
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if isOpen then
        SetNuiFocus(false, false)
    end

    weapons.disarm()
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
