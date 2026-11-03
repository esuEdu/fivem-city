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

local items = require 'data.items'
local weapons = require 'data.weapons'

---@type table<string, ItemDefinition>
local definitions = {}

---@param name string
---@param category string
---@return string
local function checkCategory(name, category)
    if Config.Categories[category] then return category end

    lib.print.warn(('Item %s has unknown category %s (not in Config.Categories), using misc'):format(name, category))

    return 'misc'
end

---@param name string
---@param data table
---@param stack boolean
---@param category string used when the item doesn't set one
---@return ItemDefinition
local function define(name, data, stack, category)
    return {
        name = name,
        label = data.label or name,
        weight = data.weight or 0,
        stack = stack,
        close = data.close ~= false,
        consume = data.consume,
        description = data.description,
        image = data.client and data.client.image or ('%s.png'):format(name),
        category = checkCategory(name, data.category or category),
    }
end

for name, data in pairs(items) do
    definitions[name] = define(name, data, data.stack ~= false, 'misc')
end

for name, data in pairs(weapons.Weapons) do
    name = name:lower()
    local item = define(name, data, false, 'weapon')
    item.weapon = true
    item.ammoname = data.ammoname
    item.clip = data.clip
    definitions[name] = item
end

for name, data in pairs(weapons.Ammo) do
    name = name:lower()
    local item = define(name, data, true, 'ammo')
    item.ammo = true
    definitions[name] = item
end

return definitions
