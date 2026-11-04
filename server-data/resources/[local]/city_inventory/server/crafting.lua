-- Crafting by dragging one item onto another, from Config.Recipes. The client just names the two slots; what they make
-- and what it costs is looked up here.

local Items = require 'shared.items'
local search = require 'shared.search'

local crafting = {}

---@class Recipe
---@field ingredients { [1]: string, [2]: integer }[]
---@field result { [1]: string, [2]: integer }
---@field duration? integer ms the player has to wait (progress bar) before it's made

---@param a string
---@param b string
---@return string
local function pairKey(a, b)
    a, b = a:lower(), b:lower()
    return a < b and ('%s|%s'):format(a, b) or ('%s|%s'):format(b, a)
end

-- Any two ingredients of a recipe, dropped one on the other, start it. The first recipe listed wins a shared pair.
---@type table<string, Recipe>
local byPair = {}

for _, recipe in ipairs(Config.Recipes) do
    local valid = Items[recipe.result[1]] ~= nil

    for _, ingredient in ipairs(recipe.ingredients) do
        valid = valid and Items[ingredient[1]] ~= nil
    end

    if not valid then
        lib.print.warn(('Recipe for %s uses an item that is not defined; skipped'):format(recipe.result[1]))
    else
        for i = 1, #recipe.ingredients do
            for j = i + 1, #recipe.ingredients do
                local key = pairKey(recipe.ingredients[i][1], recipe.ingredients[j][1])
                byPair[key] = byPair[key] or recipe
            end
        end
    end
end

---@param nameA string
---@param nameB string
---@return Recipe?
function crafting.recipeFor(nameA, nameB)
    return byPair[pairKey(nameA, nameB)]
end

---Takes the ingredients and adds the result, or changes nothing.
---@param inventory Inventory
---@param recipe Recipe
---@return boolean success
---@return string? reason
function crafting.craft(inventory, recipe)
    for _, ingredient in ipairs(recipe.ingredients) do
        if search.count(inventory.items, ingredient[1]) < ingredient[2] then
            return false, 'missing_ingredients'
        end
    end

    -- Slots are replaced, never changed in place, so a shallow copy is enough to undo
    local before = {}

    for slot, item in pairs(inventory.items) do
        before[slot] = item
    end

    for _, ingredient in ipairs(recipe.ingredients) do
        inventory:remove(ingredient[1], ingredient[2])
    end

    local success, reason = inventory:add(recipe.result[1], recipe.result[2])
    if success then return true end

    for slot = 1, inventory.slotCount do
        if inventory.items[slot] ~= before[slot] then
            inventory:setSlot(slot, before[slot])
        end
    end

    return false, reason
end

return crafting
