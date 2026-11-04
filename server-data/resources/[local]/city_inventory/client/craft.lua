-- Dropping one item onto another (ammo into a gun, an attachment onto a gun, a recipe) and the gun's right-click actions.
-- The client plays the progress bars and gives clear errors; the server checks everything again.

local Items = require 'shared.items'
local weapons = require 'client.weapons'

local craft = {}

---@class CraftHooks
---@field items fun(): table<integer, InventoryItem>
---@field canAct fun(): boolean
---@field close fun()
---@field notifyFailure fun(reason?: string)

---@type CraftHooks
local hooks

local busy = false

---@param value unknown
---@return integer?
local function toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---@param hookFns CraftHooks
function craft.init(hookFns)
    hooks = hookFns
end

---Ingredient pairs that start a recipe, so the UI can tell a craft from a move.
---@return string[][]
function craft.pairs()
    local list = {}

    for _, recipe in ipairs(Config.Recipes) do
        for i = 1, #recipe.ingredients do
            for j = i + 1, #recipe.ingredients do
                list[#list + 1] = { recipe.ingredients[i][1], recipe.ingredients[j][1] }
            end
        end
    end

    return list
end

---@param duration integer
---@param label string
---@return boolean finished
local function progress(duration, label)
    if duration <= 0 then return true end

    -- The progress bar plays in the world, not behind the inventory
    hooks.close()

    return lib.progressBar({
        duration = duration,
        label = label,
        canCancel = true,
        disable = { combat = true },
    }) and not IsPedDeadOrDying(cache.ped, true)
end

---@param fn fun()
local function run(fn)
    if busy or not hooks.canAct() then return end

    busy = true
    fn()
    busy = false
end

---@param slot integer
---@return boolean
local function isEquipped(slot)
    local item = hooks.items()[slot]
    return item ~= nil and item.metadata.serial ~= nil and item.metadata.serial == weapons.getSerial()
end

---@param fromSlot integer
---@param toSlot integer
---@param count? integer
local function load(fromSlot, toSlot, count)
    local weapon = hooks.items()[toSlot]
    local hash = joaat(weapon.name)
    local equipped = isEquipped(toSlot)

    if equipped then weapons.report() end

    -- The magazine size the server caps against (it can't read the game's weapon data)
    local clip = equipped and GetMaxAmmoInClip(cache.ped, hash, true) or GetWeaponClipSize(hash)
    local success, result = lib.callback.await('city_inventory:combine', false, fromSlot, toSlot, count, clip)

    if not success then return hooks.notifyFailure(result) end

    weapons.setAmmo(result.serial, result.ammo)
end

---@param fromSlot integer
---@param toSlot integer
local function attach(fromSlot, toSlot)
    local part, weapon = hooks.items()[fromSlot], hooks.items()[toSlot]
    if not weapons.fits(weapon.name, part.name) then return hooks.notifyFailure('component_wont_fit') end

    local definition = Items[part.name]
    local usetime = definition.client and definition.client.usetime or 0
    if not progress(usetime, locale('ui_attaching', definition.label)) then return end

    local success, reason = lib.callback.await('city_inventory:combine', false, fromSlot, toSlot)
    if not success then hooks.notifyFailure(reason) end
end

---@param fromSlot integer
---@param toSlot integer
local function make(fromSlot, toSlot)
    local success, result = lib.callback.await('city_inventory:startCraft', false, fromSlot, toSlot)
    if not success then return hooks.notifyFailure(result) end

    if not progress(result, locale('ui_crafting')) then return end

    local reason
    success, reason = lib.callback.await('city_inventory:combine', false, fromSlot, toSlot)
    if not success then hooks.notifyFailure(reason) end
end

---@param fromSlot integer
---@param toSlot integer
---@param count? integer
local function combine(fromSlot, toSlot, count)
    local from, to = hooks.items()[fromSlot], hooks.items()[toSlot]
    if not from or not to or fromSlot == toSlot then return end

    local dragged, target = Items[from.name], Items[to.name]

    if target.weapon and dragged.ammo and target.ammoname and Items[target.ammoname] == dragged then
        load(fromSlot, toSlot, count)
    elseif target.weapon and dragged.component then
        attach(fromSlot, toSlot)
    else
        make(fromSlot, toSlot)
    end
end

---@return table<string, string> attachment name -> label, for the tooltip and the Remove entries
function craft.componentLabels()
    local labels = {}

    for name, definition in pairs(Items) do
        if definition.component then labels[name] = definition.label end
    end

    return labels
end

---Double-clicking an attachment puts it on the gun in hand.
---@param slot integer
---@return boolean handled false when the item isn't an attachment
function craft.attachToEquipped(slot)
    local item = hooks.items()[slot]
    if not item or not Items[item.name].component then return false end

    local serial = weapons.getSerial()

    for weaponSlot, weapon in pairs(hooks.items()) do
        if serial and weapon.metadata.serial == serial then
            run(function() attach(slot, weaponSlot) end)
            return true
        end
    end

    hooks.notifyFailure('no_weapon')
    return true
end

RegisterNUICallback('combine', function(data, cb)
    cb(1)

    local fromSlot, toSlot = toInteger(data.from), toInteger(data.to)
    if not fromSlot or not toSlot then return end

    run(function() combine(fromSlot, toSlot, toInteger(data.count)) end)
end)

RegisterNUICallback('unload', function(data, cb)
    cb(1)

    local slot = toInteger(data.slot)
    if not slot then return end

    run(function()
        if isEquipped(slot) then weapons.report() end

        local success, result = lib.callback.await('city_inventory:unload', false, slot)
        if not success then return hooks.notifyFailure(result) end

        weapons.setAmmo(result.serial, result.ammo)
    end)
end)

RegisterNUICallback('detach', function(data, cb)
    cb(1)

    local slot = toInteger(data.slot)
    if not slot or type(data.name) ~= 'string' then return end

    run(function()
        local success, reason = lib.callback.await('city_inventory:detach', false, slot, data.name)
        if not success then hooks.notifyFailure(reason) end
    end)
end)

return craft
