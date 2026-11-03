---@class ItemDefinition
---@field name string
---@field label string
---@field weight integer
---@field stack boolean
---@field close boolean
---@field consume? number
---@field description? string
---@field image string
---@field weapon? boolean
---@field ammo? boolean
---@field ammoname? string
---@field clip? integer rounds one reload loads

local items = require 'data.items'
local weapons = require 'data.weapons'

---@type table<string, ItemDefinition>
local definitions = {}

---@param name string
---@param data table
---@param stack boolean
---@return ItemDefinition
local function define(name, data, stack)
    return {
        name = name,
        label = data.label or name,
        weight = data.weight or 0,
        stack = stack,
        close = data.close ~= false,
        consume = data.consume,
        description = data.description,
        image = data.client and data.client.image or ('%s.png'):format(name),
    }
end

for name, data in pairs(items) do
    definitions[name] = define(name, data, data.stack ~= false)
end

for name, data in pairs(weapons.Weapons) do
    name = name:lower()
    local item = define(name, data, false)
    item.weapon = true
    item.ammoname = data.ammoname
    item.clip = data.clip
    definitions[name] = item
end

for name, data in pairs(weapons.Ammo) do
    name = name:lower()
    local item = define(name, data, true)
    item.ammo = true
    definitions[name] = item
end

return definitions
