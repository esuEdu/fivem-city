-- The client side of using an item from the Qbox list: progress bar with animation and prop, then effects that need
-- the ped, as ox_inventory did. The server still decides whether the item was used (server/use.lua).

local Items = require 'shared.items'

local use = {}

-- ox_inventory's named presets (its data/animations.lua), used by anim = 'eating' / prop = 'burger'
local ANIMS = {
    eating = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },
}

local PROPS = {
    burger = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
}

---Item effects ox_inventory had built in that need the ped. Server-side ones are in server/use.lua.
---@type table<string, fun()>
local effects = {
    parachute = function()
        local chute = `GADGET_PARACHUTE`

        GiveWeaponToPed(cache.ped, chute, 0, true, false)
        SetPedGadget(cache.ped, chute, true)
    end,
}

---@param value unknown
---@param presets table
---@return unknown
local function preset(value, presets)
    return type(value) == 'string' and presets[value] or value
end

---Items whose use is a client event fire it straight away instead of asking the server, like ox_inventory.
---@param slot integer
---@param item InventoryItem
---@return boolean handled
function use.fireEvent(slot, item)
    local definition = Items[item.name]
    if not definition.event then return false end

    TriggerEvent(definition.event, definition, { name = item.name, slot = slot, metadata = item.metadata })

    return true
end

---Plays the item's progress bar, if it has one.
---@param item InventoryItem
---@return boolean finished false when the player cancelled it
function use.progress(item)
    local definition = Items[item.name]
    local client = definition.client
    if not client or not client.usetime then return true end

    return lib.progressBar({
        duration = client.usetime,
        label = client.label or locale('ui_using', item.metadata.label or definition.label),
        canCancel = client.cancel,
        disable = client.disable or { combat = true },
        anim = preset(client.anim, ANIMS) or client.scenario,
        prop = preset(client.prop, PROPS),
    }) and not IsPedDeadOrDying(cache.ped, true)
end

---Runs after the server accepted the use.
---@param item InventoryItem
function use.finish(item)
    local client = Items[item.name].client

    if effects[item.name] then
        effects[item.name]()
    end

    if client and client.notification then
        lib.notify({ description = client.notification })
    end
end

return use
