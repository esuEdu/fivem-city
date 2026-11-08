-- Starting and collecting a smelting order, for the public smelter (stamped ingots, fee) and home furnaces (slower,
-- small batches, no stamp). Recipes, times and fees come from server config; skills from the Smelter branch.
local settings = require 'server.config'
local profiles = require 'server.profiles'
local orders = require 'server.orders'
local util = require 'server.util'

local smelting = {}

---@param profile table
---@param home boolean
---@return integer
function smelting.maxBatch(profile, home)
    if home then return settings.smelter.homeMaxBatch end

    return math.floor(settings.smelter.maxBatch * (1 + profiles.skill(profile, 'batch')))
end

---What a batch needs and costs, for the menu and for start().
---@param profile table
---@param name string recipe
---@param count integer
---@param home boolean
---@return table? quote { inputs, coal, fee, seconds }
function smelting.quote(profile, name, count, home)
    local recipe = settings.recipes[name]
    if not recipe then return end
    if home and not (recipe.home or recipe.homeOnly) then return end
    if not home and recipe.homeOnly then return end

    local inputs = {}
    for _, input in ipairs(recipe.inputs) do inputs[#inputs + 1] = { input[1], input[2] * count } end

    local coal = math.ceil(recipe.coal * count * (1 - profiles.skill(profile, 'coal_save')))
    if coal > 0 then inputs[#inputs + 1] = { 'coal', coal } end

    local seconds = recipe.seconds * count * (1 - profiles.skill(profile, 'smelt_time'))
    if home then seconds = seconds * settings.smelter.homeSlowdown end

    return {
        inputs = inputs,
        coal = coal,
        fee = home and 0 or (recipe.fee or 0) * count,
        seconds = math.ceil(seconds),
    }
end

---@param src integer
---@param citizenid string
---@param place string
---@param name string
---@param count unknown
---@param home boolean
---@return boolean ok
---@return string|integer result reason or seconds
function smelting.start(src, citizenid, place, name, count, home)
    local profile = profiles.get(citizenid)
    count = math.tointeger(count)
    if type(name) ~= 'string' or not count or count < 1 or count > smelting.maxBatch(profile, home) then return false, 'invalid' end

    if orders.get(citizenid, place) or (home and orders.at(place)) then return false, 'order_open' end

    local quote = smelting.quote(profile, name, count, home)
    if not quote then return false, 'invalid' end

    -- At the public smelter, ingots used as inputs must carry the stamp
    local stampedOnly = not home and settings.ingots or nil
    if not util.takeAll(src, quote.inputs, stampedOnly) then return false, 'missing_inputs' end

    if quote.fee > 0 and not util.pay(src, quote.fee, 'mining-smelter') then
        for _, input in ipairs(quote.inputs) do
            local metadata = stampedOnly and stampedOnly[input[1]] and { stamped = true, description = locale('stamped_returned') } or nil
            exports.city_inventory:AddItem(src, input[1], input[2], metadata)
        end

        return false, 'no_money'
    end

    local stamped = not home and settings.ingots[name] == true
    if not orders.create(citizenid, place, name, count, quote.seconds, { stamped = stamped }) then return false, 'invalid' end

    return true, quote.seconds
end

---@param src integer
---@param citizenid string
---@param order table
---@return boolean ok
---@return table|string result
function smelting.collect(src, citizenid, order)
    if order.ready_at > os.time() then return false, 'not_ready' end

    local profile = profiles.get(citizenid)
    local recipe = settings.recipes[order.recipe]
    if not recipe then
        orders.close(order.id)
        return false, 'invalid'
    end

    local count = order.count

    -- Blacksmith: a chance of one extra ingot each
    if settings.ingots[order.recipe] then
        local chance = profiles.skill(profile, 'blacksmith')
        for _ = 1, order.count do
            if math.random() < chance then count = count + 1 end
        end
    end

    local metadata
    if order.data.stamped then
        local serial = ('M%06d'):format(order.id)
        metadata = { stamped = true, serial = serial, smeltedBy = order.citizenid or citizenid, description = locale('stamped_description', serial) }
    end

    if not exports.city_inventory:CanCarryItem(src, order.recipe, count, metadata) then return false, 'inventory_full' end
    if not orders.close(order.id) then return false, 'invalid' end

    exports.city_inventory:AddItem(src, order.recipe, count, metadata)

    local levelUp = profiles.addXp(profile, (recipe.xp or 0) * order.count)

    return true, { drops = { { item = order.recipe, count = count } }, levelUp = levelUp }
end

---Order state for menus.
---@param order table?
---@return table?
function smelting.view(order)
    if not order then return end

    return { recipe = order.recipe, count = order.count, secondsLeft = math.max(0, order.ready_at - os.time()) }
end

return smelting
