---@class ItemDefinition
---@field name string
---@field label string
---@field weight integer
---@field stack boolean
---@field close boolean
---@field consume? number
---@field description? string
---@field image string
---@field category string key of Config.Categories
---@field weapon? boolean
---@field ammo? boolean
---@field ammoname? string
---@field clip? integer rounds one reload loads
---@field client? table ox_inventory-style use data: status, anim, prop, usetime, event, notification, add, remove
---@field status? table<string, number> statuses changed on use (hunger, thirst, stress)
---@field event? string client event fired on use

local items = require 'data.items'
local weapons = require 'data.weapons'

---@type table<string, ItemDefinition>
local definitions = {}

---@type table<string, true>
local categoryNames = {}

for _, category in ipairs(Config.Categories) do
    categoryNames[category.name] = true
end

---@param name string
---@param category string
---@return string
local function checkCategory(name, category)
    if categoryNames[category] then return category end

    lib.print.warn(('Item %s has unknown category %s (not in Config.Categories), using misc'):format(name, category))

    return 'misc'
end

---@param name string
---@param data table
---@param stack boolean
---@param category string used when the item doesn't set one
---@return ItemDefinition
local function define(name, data, stack, category)
    local client = data.client

    -- Like ox_inventory: items used with a status change or a progress bar use up one by default
    local consume = data.consume
    if consume == nil and client and (client.status or client.usetime) then
        consume = 1
    end

    return {
        name = name,
        label = data.label or name,
        weight = data.weight or 0,
        stack = stack,
        close = data.close ~= false,
        consume = consume,
        description = data.description,
        image = client and client.image or ('%s.png'):format(name:lower()),
        category = checkCategory(name, data.category or category),
        client = client,
        status = client and client.status,
        event = client and client.event,
    }
end

for name, data in pairs(items) do
    definitions[name] = define(name, data, data.stack ~= false, 'misc')
end

for name, data in pairs(weapons.Weapons) do
    local item = define(name, data, false, 'weapon')
    item.weapon = true
    item.ammoname = data.ammoname
    item.clip = data.clip
    definitions[name] = item
end

for name, data in pairs(weapons.Components) do
    definitions[name] = define(name, data, true, 'weapon')
end

for name, data in pairs(weapons.Ammo) do
    local item = define(name, data, true, 'ammo')
    item.ammo = true
    definitions[name] = item
end

-- Names are stored as written in data/ (WEAPON_PISTOL, ammo-9, water), but looked up in any case:
-- scripts written for ox_inventory use WEAPON_PISTOL, admins type weapon_pistol.
---@type table<string, string>
local byLowerName = {}

for name in pairs(definitions) do
    byLowerName[name:lower()] = name
end

return setmetatable(definitions, {
    __index = function(_, name)
        local canonical = type(name) == 'string' and byLowerName[name:lower()]
        return canonical and rawget(definitions, canonical)
    end,
})
